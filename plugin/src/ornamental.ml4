DECLARE PLUGIN "ornamental"

open Term
open Names
open Environ
open Constrarg
open Utilities
open Coqterms
open Printing
open Differencing
open Lifting
open Promotions
open Specialization

(* --- Top-level --- *)

(* Identify an ornament *)
let find_ornament n d_old d_new =
  let (evm, env) = Lemmas.get_current_context () in
  let trm_o = unwrap_definition env (intern env evm d_old) in
  let trm_n = unwrap_definition env (intern env evm d_new) in
  if isInd trm_o && isInd trm_n then
    let idx_n = with_suffix n "index" in
    let orn = search_orn_inductive env evm idx_n trm_o trm_n in
    let idx = orn.indexer in
    (if Option.has_some idx then
       let _ = define_term idx_n env evm (Option.get idx) in
       Printf.printf "Defined indexing function %s.\n\n" (string_of_id idx_n);
     else
       ());
    define_term n env evm orn.promote;
    Printf.printf "Defined promotion %s.\n\n" (string_of_id n);
    let inv_n = with_suffix n "inv" in
    define_term inv_n env evm orn.forget;
    Printf.printf "Defined forgetful function %s.\n\n" (string_of_id inv_n);
    ()
  else
    failwith "Only inductive types are supported"

(* Apply an ornament, but don't reduce *)
let apply_ornament n d_orn d_orn_inv d_old =
  let (evd, env) = Lemmas.get_current_context () in
  let c_orn = intern env evd d_orn in
  let c_orn_inv = intern env evd d_orn_inv in
  let c_o = intern env evd d_old in
  let is_fwd = direction env evd c_orn in
  let (promote, forget) = map_if reverse (not is_fwd) (c_orn, c_orn_inv) in
  let orn = initialize_promotion env evd promote forget in
  let l = initialize_lifting orn is_fwd in
  let trm_n = apply_indexing_ornament env evd l c_o in
  define_term n env evd trm_n;
  Printf.printf "Defined ornamented fuction %s.\n\n" (string_of_id n);
  ()

(* Reduce an application of an ornament *)
let reduce_ornament n d_orn d_orn_inv d_old =
  let (evd, env) = Lemmas.get_current_context () in
  let c_orn = intern env evd d_orn in
  let c_orn_inv = intern env evd d_orn_inv in
  let c_o = intern env evd d_old in
  let trm_o = unwrap_definition env c_o in
  let idx_n = with_suffix n "index" in
  let is_fwd = direction env evd c_orn in
  let (promote, forget) = map_if reverse (not is_fwd) (c_orn, c_orn_inv) in
  let orn = initialize_promotion env evd promote forget in
  let l = initialize_lifting orn is_fwd in
  let (trm_n, indexer) = internalize env evd idx_n l trm_o in
  (if Option.has_some indexer then
     let indexer_o = Option.get indexer in
     let (indexer_n, _) = internalize env evd idx_n l indexer_o in
     define_term idx_n env evd indexer_n;
     Printf.printf "Defined indexer %s.\n\n" (string_of_id idx_n)
   else
     ());
  define_term n env evd trm_n;
  Printf.printf "Defined reduced ornamened function %s.\n\n" (string_of_id n);
  ()

(* Higher lifting *)
let higher_lifting n d_orn d_orn_inv d_f_old d_f_new d_old =
  let (evd, env) = Lemmas.get_current_context () in
  let c_orn = intern env evd d_orn in
  let c_orn_inv = intern env evd d_orn_inv in
  let c_f_old = intern env evd d_f_old in
  let c_f_new = intern env evd d_f_new in
  let c_o = intern env evd d_old in
  let is_fwd = direction env evd c_orn in
  let (promote, forget) = map_if reverse (not is_fwd) (c_orn, c_orn_inv) in
  let (promote_f, forget_f) = map_if reverse (not is_fwd) (c_f_old, c_f_new) in
  let orn = initialize_promotion env evd promote forget in
  let lower = Some (initialize_lifting orn is_fwd) in
  let higher_orn = initialize_promotion env evd c_f_old c_f_new in
  let higher = initialize_lifting higher_orn is_fwd in
  let l = { higher with lower } in
  (* TODO implement from here on, config higher lifting then run *)
  let trm_n = unwrap_definition env c_o in
  define_term n env evd trm_n 

(* --- Commands --- *)

(* Identify an ornament given two inductive types *)
VERNAC COMMAND EXTEND FindOrnament CLASSIFIED AS SIDEFF
| [ "Find" "ornament" constr(d_old) constr(d_new) "as" ident(n)] ->
  [ find_ornament n d_old d_new ]
END

(*
 * Given an ornament and a function, derive the ornamented version that
 * doesn't internalize the ornament.
 *
 * This is equivalent to porting the hypotheses and conclusions we apply
 * the function to via the ornament, but not actually reducing the
 * result to get something of a useful type. It's the first step in
 * lifting functions, which will be chained eventually to lift
 * functions entirely.
 *)
VERNAC COMMAND EXTEND ApplyOrnament CLASSIFIED AS SIDEFF
| [ "Apply" "ornament" constr(d_orn) constr(d_orn_inv) "in" constr(d_old) "as" ident(n)] ->
  [ apply_ornament n d_orn d_orn_inv d_old ]
END

(*
 * Meta-reduce an application of an ornament.
 * This command should always preserve the type of the argument,
 * but produce a term inducts over the new domain and reduces
 * internal application as much as possible. So for simple
 * functions, this will be enough, but for proofs, there is one more step.
 *)
VERNAC COMMAND EXTEND ReduceOrnament CLASSIFIED AS SIDEFF
| [ "Reduce" "ornament" constr(d_orn) constr(d_orn_inv) "in" constr(d_old) "as" ident(n)] ->
  [ reduce_ornament n d_orn d_orn_inv d_old ]
END

(*
 * The higher-lifting step is not type-preserving, but instead
 * takes a meta-reduced application and substitutes in an already-lifted
 * type that still occurs in the meta-reduced term and type.
 *)
VERNAC COMMAND EXTEND HigherLifting CLASSIFIED AS SIDEFF
| [ "Higher" "lift" constr(d_orn) constr(d_orn_inv) "in" constr(d_old) "along" constr(d_f_old) constr (d_f_new) "as" ident(n) ] ->
  [ higher_lifting n d_orn d_orn_inv d_f_old d_f_new d_old ]
END
