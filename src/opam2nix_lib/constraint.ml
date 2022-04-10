let to_nix (op, filter) =
  let open Nix in
  let scope = ident "__constraintScope" in
  lambda
    (Pattern.ident "__constraintScope")
    (apply (index scope (Common.string_of_relop op)) [ Filter.to_nix filter ])
;;
