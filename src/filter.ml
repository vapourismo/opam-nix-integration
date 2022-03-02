let eval ?(default = false) env filter = OpamFilter.eval_to_bool ~default env filter

let apply_to_list ?default env items =
  List.filter_map
    (fun (item, filter) ->
      match filter with
      | Some filter when not (eval ?default env filter) -> None
      | _ -> Some item)
    items
;;

let string_of_relop op =
  match op with
  | `Eq -> "equal"
  | `Neq -> "notEqual"
  | `Geq -> "greaterEqual"
  | `Gt -> "greaterThan"
  | `Leq -> "lowerEqual"
  | `Lt -> "lowerThan"
;;

let nix_of_filter filter =
  let open Nix in
  let scope = Nix.ident "__filterScope" in
  let rec go = function
    | OpamTypes.FBool value -> apply (index scope "bool") [ bool value ]
    | FString value -> apply (index scope "string") [ string value ]
    | FIdent (packages, name, defaults) ->
      let packages =
        List.map
          (function
              | None -> null
              | Some package -> string (OpamPackage.Name.to_string package))
          packages
      in
      let defaults =
        match defaults with
        | None -> []
        | Some (if_true, otherwise) ->
          [ "if_true", string if_true; "otherwise", string otherwise ]
      in
      apply
        (index scope "ident")
        [ list packages; string (OpamVariable.to_string name); attr_set defaults ]
    | FOp (left, op, right) ->
      apply (index scope (string_of_relop op)) [ go left; go right ]
    | FAnd (left, right) -> apply (index scope "and") [ go left; go right ]
    | FOr (left, right) -> apply (index scope "or") [ go left; go right ]
    | FNot filter -> apply (index scope "not") [ go filter ]
    | FDefined filter -> apply (index scope "def") [ go filter ]
    | FUndef filter -> apply (index scope "undef") [ go filter ]
  in
  lambda (Pattern.ident "__filterScope") (go filter)
;;
