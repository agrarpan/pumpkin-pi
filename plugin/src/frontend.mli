open Constrexpr
open Constr
open Names
open Environ

type ornamental_action = env -> Evd.evar_map -> constr -> constr -> constr -> constr * constr option
type ornamental_command = Id.t -> constr_expr -> constr_expr -> constr_expr -> unit

(* Identify an algebraic ornament between two types and define its conversion functions  *)
val find_ornament : Id.t -> constr_expr -> constr_expr -> unit

(* Apply (i.e., lift across) an ornament without meta-reduction *)
val apply_ornament : ornamental_action

(* Meta-reduce a ornamental lifting *)
val reduce_ornament : ornamental_action

(* Post-facto modularization of a meta-reduced ornamental lifting/application *)
val modularize_ornament : ornamental_action

(* Perform application, meta-reduction, and modularization all in sequence *)
val lift_by_ornament : ornamental_action

(* Transform an ornamental action into an ornamental command *)
val make_ornamental_command : ornamental_action -> ornamental_command
