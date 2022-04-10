open OpamTypes

(** *)
val nix_of_variable
  :  name option list
  -> OpamVariable.t
  -> (string * string) option
  -> Nix.t

(** *)
val nix_of_ident_string : string -> Nix.t

(** *)
val nix_of_interpolated_string : string -> Nix.t
