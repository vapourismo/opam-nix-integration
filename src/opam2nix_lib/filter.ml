let to_nix filter =
  let open Nix in
  scoped "__filterScope" (fun scope ->
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
      go filter)
;;

let nix_of_true = to_nix (OpamTypes.FBool true)
