let to_nix filter =
  let open Nix in
  let scope = ident "__filterScope" in
  let rec go = function
    | OpamTypes.FBool value -> index scope "bool" @@ [ bool value ]
    | FString value -> index scope "string" @@ [ string value ]
    | FIdent (packages, name, defaults) ->
      index scope "ident" @@ [ Env.nix_of_variable packages name defaults ]
    | FOp (left, op, right) ->
      index scope (Common.string_of_relop op) @@ [ go left; go right ]
    | FAnd (left, right) -> index scope "and" @@ [ go left; go right ]
    | FOr (left, right) -> index scope "or" @@ [ go left; go right ]
    | FNot filter -> index scope "not" @@ [ go filter ]
    | FDefined filter -> index scope "def" @@ [ go filter ]
    | FUndef filter -> index scope "undef" @@ [ go filter ]
  in
  lambda (Pattern.ident "__filterScope") (go filter)
;;

let nix_of_true =
  let open Nix in
  lambda
    (Pattern.ident "__filterScope")
    (index (ident "__filterScope") "bool" @@ [ bool true ])
;;
