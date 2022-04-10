let to_nix (op, filter) =
  let open Nix in
  scoped "__constraintScope" (fun scope ->
      index scope (Common.string_of_relop op) @@ [ Filter.to_nix filter ])
;;
