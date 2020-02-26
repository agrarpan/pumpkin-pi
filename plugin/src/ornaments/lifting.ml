(*
 * Datatypes for promotions and lifting
 *)

open Declarations
open Utilities
open Constr
open Environ
open Apputils
open Sigmautils
open Typehofs
open Zooming
open Envutils
open Hofimpls
open Caching
open Funutils
open Inference
open Promotion
open Indexing
open Ornerrors
open Stateutils
open Reducers
open Debruijn

(* --- Datatypes --- *)

(*
 * A lifting is an ornamental promotion between types and a direction,
 * This is a convenience configuration for lifting functions and proofs,
 * which wraps the promotion with extra useful information.
 *)
type lifting =
  {
    orn : promotion;
    is_fwd : bool;
  }

(* --- Control structures --- *)
    
(*
 * These two functions determine what function to use to go back to
 * an old type or get to a new type when lifting
 *)
let lift_back (l : lifting) = if l.is_fwd then l.orn.forget else l.orn.promote
let lift_to (l : lifting) = if l.is_fwd then l.orn.promote else l.orn.forget

(* Other control structures *)
let directional l a b = if l.is_fwd then a else b
let map_directional f g l x = map_if_else f g l.is_fwd x
let map_forward f l x = map_if f l.is_fwd x
let map_backward f l x = map_if f (not l.is_fwd) x
               
(* --- Information retrieval --- *)

(* 
 * Given the type of an ornamental promotion function, get the types
 * that the function maps between, including all of their arguments 
 *)
let rec promotion_type_to_types (typ : types) : types * types =
  match kind typ with
  | Prod (n, t, b) when isProd b ->
     promotion_type_to_types b
  | Prod (n, t, b) ->
     (t, b)
  | _ ->
     failwith "not an ornamental promotion/forgetful function type"

(* 
 * Same, but at the term level
 *)
let promotion_term_to_types env sigma trm =
  on_red_type_default (ignore_env promotion_type_to_types) env sigma trm

(* --- Utilities for initialization --- *)

(*
 * Determine if the direction is forwards or backwards
 * That is, if trm is a promotion or a forgetful function
 * True if forwards, false if backwards
 *)
let direction_cached env from_typ promote k sigma : bool state =
  let promote = unwrap_definition env promote in
  let promote_env = zoom_env zoom_lambda_term env promote in
  let sigma, promote_typ = infer_type promote_env sigma (mkRel 1) in
  sigma, is_or_applies from_typ promote_typ

(* 
 * Unpack a promotion
 *)
let unpack_promotion env promotion =
  let (env_promotion, body) = zoom_lambda_term env promotion in
  reconstruct_lambda env_promotion (last_arg body)

(*
 * Get the direction for an uncached ornament.
 *)
let get_direction (from_typ_app, to_typ_app) orn_kind =
  match orn_kind with
  | Algebraic _ ->
     let rec get_direction_algebraic (from_ind, to_ind) =
       if not (applies sigT from_ind) then
         true
       else
         if not (applies sigT to_ind) then
           false
         else
           let (from_args, to_args) = map_tuple unfold_args (from_ind, to_ind) in
           get_direction_algebraic (map_tuple last (from_args, to_args))
     in get_direction_algebraic (from_typ_app, to_typ_app)
  | CurryRecord ->
     not (equal Produtils.prod (first_fun from_typ_app))
  | SwapConstruct _ ->
     true

(*
 * For an uncached ornament, get the kind and its direction
 *)
let get_kind_of_ornament env (o, n) sigma =
  let (from_typ_app, to_typ_app) = promotion_term_to_types env sigma o in
  let prelim_kind =
    if applies sigT from_typ_app || applies sigT to_typ_app then
      Algebraic (mkRel 1, 0)
    else if isInd (first_fun from_typ_app) && isInd (first_fun to_typ_app) then
      SwapConstruct []
    else
      CurryRecord
  in
  match prelim_kind with
  | Algebraic _ ->
     let is_fwd = get_direction (from_typ_app, to_typ_app) prelim_kind in
     let (promote, _) = map_if reverse (not is_fwd) (o, n) in
     let promote_unpacked = unpack_promotion env (unwrap_definition env promote) in
     let to_ind = snd (promotion_term_to_types env sigma promote_unpacked) in
     let to_args = unfold_args to_ind in
     let to_args_idx = List.mapi (fun i t -> (i, t)) to_args in
     let (o, i) = List.find (fun (_, t) -> contains_term (mkRel 1) t) to_args_idx in
     let indexer = first_fun i in
     sigma, (is_fwd, Algebraic (indexer, o))
  | CurryRecord ->
     let is_fwd = get_direction (from_typ_app, to_typ_app) prelim_kind in
     sigma, (is_fwd, CurryRecord)
  | SwapConstruct _ ->
     let promote = o in
     let sigma, promote_type = reduce_type env sigma promote in
     let ((i_o, ii_o), u_o) = destInd (first_fun from_typ_app) in
     let m_o = lookup_mind i_o env in
     let b_o = m_o.mind_packets.(0) in
     let cs_o = b_o.mind_consnames in
     let ncons = Array.length cs_o in
     let sigma, swap_map =
       map_state
         (fun i sigma ->
           let c_o = mkConstructU (((i_o, ii_o), i), u_o) in
           let sigma, c_o_typ = reduce_type env sigma c_o in
           let env_c_o, c_o_typ = zoom_product_type env c_o_typ in
           let nargs = new_rels2 env_c_o env in
           let c_o_args = mk_n_rels nargs in
           let c_o_app = mkAppl (c_o, c_o_args) in
           let typ_args = unfold_args c_o_typ in
           let sigma, c_o_lifted = reduce_nf env_c_o sigma (mkAppl (promote, snoc c_o_app typ_args)) in
           let ((_, j), _) = destConstruct (first_fun c_o_lifted) in
           sigma, (i, j))
         (range 1 (ncons + 1))
         sigma
     in sigma, (true, SwapConstruct swap_map)

(* --- Initialization --- *)

(*
 * Initialize a lifting for a cached ornament
 *)
let initialize_lifting_cached env sigma o n =
  let sigma, (is_fwd, (promote, forget), kind) =
    let (promote, forget, k) =
      try
        Option.get (lookup_ornament (o, n))
      with _ ->
        failwith "Cannot find cached ornament! Please report a bug in DEVOID"
    in
    let sigma, is_fwd = direction_cached env o promote k sigma in
    sigma, (is_fwd, (promote, forget), k)
  in
  let orn = { promote; forget; kind } in
  sigma, { orn ; is_fwd }

(*
 * Initialize a lifting for a user-provided ornament
 *)
let initialize_lifting_provided env sigma o n =
  let sigma, (is_fwd, (promote, forget), kind) =
    let sigma, (is_fwd, k) = get_kind_of_ornament env (o, n) sigma in
    let orns = map_if reverse (not is_fwd) (o, n) in
    sigma, (is_fwd, orns, k)
  in
  let orn = { promote; forget; kind } in
  sigma, { orn ; is_fwd }

(* --- Directionality --- *)
       
(* 
 * Flip the direction of a lifting
 *)
let flip_dir l = { l with is_fwd = (not l.is_fwd) }

(*
 * Apply a function twice, once in each direction.
 * Compose the result into a tuple.
 *)
let twice_directional f l = map_tuple f (l, flip_dir l)

(* --- Indexing for algebraic ornaments --- *)

let index l =
  match l.orn.kind with
  | Algebraic (_, off) ->
     insert_index off
  | _ ->
     raise NotAlgebraic

let deindex l =
  match l.orn.kind with
  | Algebraic (_, off) ->
     remove_index off
  | _ ->
     raise NotAlgebraic
