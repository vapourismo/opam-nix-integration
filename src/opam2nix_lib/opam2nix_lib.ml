let nix_of_variable_scoped scope packages name defaults =
  let open Nix in
  let packages = List.filter_map (Option.map OpamPackage.Name.to_string) packages in
  let defaults =
    match defaults with
    | None -> null
    | Some (if_true, otherwise) ->
      attr_set [ "ifTrue", string if_true; "otherwise", string otherwise ]
  in
  let resolve_local_var () =
    index scope "local"
    @@ [ attr_set [ "name", string (OpamVariable.to_string name); "defaults", defaults ] ]
  in
  let resolve_package_var package =
    if package == "_"
    then resolve_local_var ()
    else
      index scope "package"
      @@ [ attr_set
             [ "packageName", string package
             ; "name", string (OpamVariable.to_string name)
             ; "defaults", defaults
             ]
         ]
  in
  match packages with
  | [] | [ "_" ] -> resolve_local_var ()
  | [ package ] -> resolve_package_var package
  | packages -> index scope "combine" @@ [ list (List.map resolve_package_var packages) ]
;;

let nix_of_variable packages name defaults =
  let open Nix in
  lambda
    (Pattern.ident "__envScope")
    (nix_of_variable_scoped (ident "__envScope") packages name defaults)
;;

let nix_of_variable_string_scoped scope name =
  let packages, name, defaults = OpamTypesBase.filter_ident_of_string name in
  nix_of_variable_scoped scope packages name defaults
;;

let nix_of_variable_string ?(force_string = false) name =
  let open Nix in
  let force body =
    if force_string then ident "__envScope.toString" @@ [ body ] else body
  in
  lambda
    (Pattern.ident "__envScope")
    (force (nix_of_variable_string_scoped (ident "__envScope") name))
;;

let nix_of_interpolated_string_scoped scope input =
  let open Nix in
  let segments =
    Interpolated_string.parse
      ~on_string:(fun str -> StringSegment str)
      ~on_variable:(fun name ->
        CodeSegment
          (index scope "toString" @@ [ nix_of_variable_string_scoped scope name ]))
      input
  in
  MultilineString [ segments ]
;;

let nix_of_interpolated_string input =
  let open Nix in
  lambda
    (Pattern.ident "__envScope")
    (nix_of_interpolated_string_scoped (ident "__envScope") input)
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
  let scope = ident "__filterScope" in
  let rec go = function
    | OpamTypes.FBool value -> index scope "bool" @@ [ bool value ]
    | FString value -> index scope "string" @@ [ string value ]
    | FIdent (packages, name, defaults) ->
      index scope "ident" @@ [ nix_of_variable packages name defaults ]
    | FOp (left, op, right) -> index scope (string_of_relop op) @@ [ go left; go right ]
    | FAnd (left, right) -> index scope "and" @@ [ go left; go right ]
    | FOr (left, right) -> index scope "or" @@ [ go left; go right ]
    | FNot filter -> index scope "not" @@ [ go filter ]
    | FDefined filter -> index scope "def" @@ [ go filter ]
    | FUndef filter -> index scope "undef" @@ [ go filter ]
  in
  lambda (Pattern.ident "__filterScope") (go filter)
;;

let nix_of_true_filter =
  let open Nix in
  lambda
    (Pattern.ident "__filterScope")
    (index (ident "__filterScope") "bool" @@ [ bool true ])
;;

let nix_of_formula to_nix formula =
  let open Nix in
  let scope = ident "__formulaScope" in
  let rec go formula =
    match formula with
    | OpamFormula.Empty -> index scope "empty"
    | Atom atom -> index scope "atom" @@ [ to_nix atom ]
    | Block formula -> go formula
    (* The formula is in CNF, these two cases should never happen because [go] is called on
       "atom"-like items of the formula. *)
    | And _ -> failwith "CNF conversion failed!"
    | Or _ -> failwith "CNF conversion failed!"
  in
  let body =
    OpamFormula.cnf_of_formula formula
    |> OpamFormula.ands_to_list
    |> List.map (fun ors -> OpamFormula.ors_to_list ors |> List.map go |> list)
    |> list
  in
  lambda (Pattern.ident "__formulaScope") body
;;

let nix_of_constraint (op, filter) =
  let open Nix in
  let scope = ident "__constraintScope" in
  lambda
    (Pattern.ident "__constraintScope")
    (apply (index scope (string_of_relop op)) [ nix_of_filter filter ])
;;

let nix_of_dependency ?(optional = false) (name, formula) =
  let open Nix in
  let scope = ident "__dependencyScope" in
  let constraints =
    OpamFormula.map
      (fun atom ->
        match atom with
        | OpamTypes.Filter _ -> OpamTypes.Empty
        | Constraint body -> OpamTypes.Atom body)
      formula
  in
  let enabled =
    OpamFormula.map
      (fun atom ->
        match atom with
        | OpamTypes.Constraint _ -> OpamTypes.Empty
        | Filter filter -> OpamFormula.Atom filter)
      formula
  in
  lambda
    (Pattern.ident "__dependencyScope")
    (apply
       (index scope (if optional then "optionalPackage" else "package"))
       [ string (OpamPackage.Name.to_string name)
       ; nix_of_formula nix_of_filter enabled
       ; nix_of_formula nix_of_constraint constraints
       ])
;;

let nix_of_depends depends = nix_of_formula nix_of_dependency depends

let nix_of_depopts depots = nix_of_formula (nix_of_dependency ~optional:true) depots

let nix_of_depexts depexts =
  let open Nix in
  list
    (List.map
       (fun (packages, filter) ->
         attr_set
           [ ( "packages"
             , list
                 (List.map
                    (fun package -> string (OpamSysPkg.to_string package))
                    (OpamSysPkg.Set.elements packages)) )
           ; "filter", nix_of_filter filter
           ])
       depexts)
;;

let nix_of_args args =
  let open Nix in
  list
    (List.map
       (fun (arg, filter) ->
         let filter = Option.fold ~none:nix_of_true_filter ~some:nix_of_filter filter in
         let arg =
           match arg with
           | OpamTypes.CString str -> nix_of_interpolated_string str
           | CIdent name -> nix_of_variable_string ~force_string:true name
         in
         attr_set [ "filter", filter; "arg", arg ])
       args)
;;

let nix_of_commands commands =
  let open Nix in
  list
    (List.map
       (fun (args, filter) ->
         let filter = Option.fold ~none:nix_of_true_filter ~some:nix_of_filter filter in
         attr_set [ "filter", filter; "args", nix_of_args args ])
       commands)
;;
