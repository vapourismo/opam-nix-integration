let string_of_relop op =
  match op with
  | `Eq -> "equal"
  | `Neq -> "notEqual"
  | `Geq -> "greaterEqual"
  | `Gt -> "greaterThan"
  | `Leq -> "lowerEqual"
  | `Lt -> "lowerThan"
;;

let nix_of_ident scope packages name defaults =
  let open Nix in
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
;;

let nix_of_ident_string scope name =
  let packages, name, defaults = OpamTypesBase.filter_ident_of_string name in
  nix_of_ident scope packages name defaults
;;

let nix_of_filter filter =
  let open Nix in
  let scope = ident "__filterScope" in
  let rec go = function
    | OpamTypes.FBool value -> apply (index scope "bool") [ bool value ]
    | FString value -> apply (index scope "string") [ string value ]
    | FIdent (packages, name, defaults) -> nix_of_ident scope packages name defaults
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

let nix_of_true =
  let open Nix in
  lambda
    (Pattern.ident "__filterScope")
    (apply (index (ident "__filterScope") "bool") [ bool true ])
;;

let nix_of_formula to_nix formula =
  let open Nix in
  let scope = ident "__formulaScope" in
  let rec go formula =
    match formula with
    | OpamFormula.Empty -> index scope "empty"
    | Atom atom -> apply (index scope "atom") [ to_nix atom ]
    | Block formula -> go formula
    (* The formula is in CNF, these two cases should never happen. *)
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

let nix_of_dependency (name, formula) =
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
       (index scope "package")
       [ string (OpamPackage.Name.to_string name)
       ; nix_of_formula nix_of_filter enabled
       ; nix_of_formula nix_of_constraint constraints
       ])
;;

let nix_of_depends depends = nix_of_formula nix_of_dependency depends

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

let interpolated_string_parser scope =
  let open Angstrom in
  let variable =
    string "%{" *> many1 (satisfy (fun c -> c <> '}'))
    <* string "}%"
    >>| fun chars ->
    List.to_seq chars
    |> String.of_seq
    |> nix_of_ident_string scope
    |> fun code -> Nix.CodeSegment code
  in
  let not_variable =
    many1 (satisfy (fun c -> c <> '%'))
    >>| fun chars ->
    List.to_seq chars |> String.of_seq |> fun str -> Nix.StringSegment str
  in
  many (variable <|> not_variable) >>| fun segments -> Nix.String segments
;;

let nix_of_args args =
  let open Nix in
  list
    (List.map
       (fun (arg, filter) ->
         let filter = Option.fold ~none:nix_of_true ~some:nix_of_filter filter in
         let arg =
           match arg with
           | OpamTypes.CString str ->
             Result.fold
               ~ok:Fun.id
               ~error:failwith
               Angstrom.(
                 parse_string
                   ~consume:All
                   (interpolated_string_parser (ident "__argScope"))
                   str)
           | CIdent name -> nix_of_ident_string (ident "__argScope") name
         in
         attr_set [ "filter", filter; "arg", lambda (Pattern.ident "__argScope") arg ])
       args)
;;

let nix_of_commands commands =
  let open Nix in
  list
    (List.map
       (fun (args, filter) ->
         let filter = Option.fold ~none:nix_of_true ~some:nix_of_filter filter in
         attr_set [ "filter", filter; "args", nix_of_args args ])
       commands)
;;
