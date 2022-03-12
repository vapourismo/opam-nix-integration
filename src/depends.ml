let nix_of_formula to_nix formula =
  let open Nix in
  let scope = ident "__formulaScope" in
  let rec go formula =
    match formula with
    | OpamFormula.Empty -> index scope "empty"
    | Atom atom -> apply (index scope "atom") [ to_nix atom ]
    | Block formula -> apply (index scope "block") [ go formula ]
    | And (left, right) -> apply (index scope "and") [ go left; go right ]
    | Or (left, right) -> apply (index scope "or") [ go left; go right ]
  in
  lambda (Pattern.ident "__formulaScope") (go formula)
;;

let nix_of_filter_or_constraint filter =
  let open Nix in
  let scope = ident "__filterOrConstraintScope" in
  lambda
    (Pattern.ident "__filterOrConstraintScope")
    (match filter with
    | OpamTypes.Filter filter ->
      apply (index scope "always") [ Filter.nix_of_filter filter ]
    | Constraint (op, filter) ->
      apply (index scope (Filter.string_of_relop op)) [ Filter.nix_of_filter filter ])
;;

let nix_of_dependency (name, formula) =
  let open Nix in
  let scope = ident "__dependencyScope" in
  lambda
    (Pattern.ident "__dependencyScope")
    (apply
       (index scope "package")
       [ string (OpamPackage.Name.to_string name)
       ; nix_of_formula nix_of_filter_or_constraint formula
       ])
;;

let transform_depends depends = nix_of_formula nix_of_dependency depends

let transform_native_depends depexts =
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
           ; "filter", Filter.nix_of_filter filter
           ])
       depexts)
;;

let all depends =
  OpamFormula.map
    (fun (name, _formula) -> OpamFormula.Atom (name, OpamFormula.Empty))
    depends
  |> OpamFormula.atoms
  |> List.map OpamFormula.string_of_atom
;;
