let transform_formula resolve_atom scope formula =
  let open Nix in
  let rec go formula =
    match formula with
    | OpamFormula.Empty -> index scope "empty"
    | Atom atom -> resolve_atom atom
    | Block formula -> go formula
    | And (left, right) -> apply (index scope "and") [ go left; go right ]
    | Or (left, right) -> apply (index scope "or") [ go left; go right ]
  in
  go formula
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

let transform_filter env filter =
  match OpamFilter.eval env filter with
  | OpamTypes.S value -> Nix.string value
  | OpamTypes.B value -> Nix.bool value
  | OpamTypes.L values -> Nix.list (List.map Nix.string values)
;;

let transform_filter_or_constraint env constraint_scope = function
  | OpamTypes.Filter filter -> transform_filter env filter
  | Constraint (op, filter) ->
    Nix.apply
      (Nix.index constraint_scope (string_of_relop op))
      [ transform_filter env filter ]
;;

let transform_depends env depends =
  let open Nix in
  let package_when = "__packageWhen" in
  let formula_scope = "__formulaScope" in
  let constraint_scope = "__constraintScope" in
  let expression =
    lambda
      (Pattern.attr_set [ package_when; formula_scope; constraint_scope ])
      (transform_formula
         (fun (name, formula) ->
           apply
             (ident package_when)
             [ ident (OpamPackage.Name.to_string name)
             ; transform_formula
                 (transform_filter_or_constraint env (ident constraint_scope))
                 (ident formula_scope)
                 formula
             ])
         (ident formula_scope)
         depends)
  in
  let atoms =
    OpamFormula.map
      (fun (name, _formula) -> OpamFormula.Atom (name, OpamFormula.Empty))
      depends
    |> OpamFormula.atoms
    |> List.map OpamFormula.string_of_atom
  in
  atoms, expression
;;
