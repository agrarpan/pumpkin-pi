open Util
open Names
open Libnames
open Univ
open Context
(* open Pretyping *)
open CErrors
open Coqterms
open Ltac_plugin

let tactic_script =
  Qualid (qualid_of_string "Ornamental.Unpack.unpack") |> CAst.make

(* Evaluate a tactic on no goals and return any proofs constructed *)
let eval_tactic env evm ?goal tac =
  let typ, _ = Evarutil.e_new_type_evar env evm Evd.univ_flexible_alg in
  let (ent, pv) = Proofview.init !evm [(env, typ)] in
  let ((), pv, (unsafe, shelved, obliged), _) = Proofview.apply env tac pv in
  evm := Proofview.proofview pv |> snd;
  (* evm := TODO: solve_remaining_evars (default_inference_flags true) env evm evm0; *)
  let proofs = Proofview.partial_proof ent pv |> List.map (EConstr.to_constr !evm) in
  (* let shelved = List.filter (Evd.is_undefined !evm) shelved in
   * let obliged = List.filter (Evd.is_undefined !evm) obliged in
   * List.iter (Printer.pr_constr_env env !evm %> Feedback.msg_debug) proofs;
   * List.map (Printer.pr_existential_key !evm) obliged |> Pp.seq |> Feedback.msg_debug;
   * List.map (Printer.pr_existential_key !evm) shelved |> Pp.seq |> Feedback.msg_debug; *)
  List.hd proofs

let call_tactic env evm tac args =
  let open Tacexpr in
  let args = List.map (fun e -> ConstrMayEval (Genredexpr.ConstrTerm e)) args in
  TacArg (Loc.tag (TacCall (Loc.tag (tac, args)))) |> Tacinterp.interp |>
  eval_tactic env evm

let unpack_constant env evm const =
  let term = Evarutil.e_new_global evm (ConstRef const) in
  call_tactic env evm tactic_script [Constrextern.extern_constr false env !evm term]
