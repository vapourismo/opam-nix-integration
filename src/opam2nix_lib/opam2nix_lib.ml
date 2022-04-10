module Interpolated_string = Interpolated_string
module Env = Env
module Constraint = Constraint
module Filter = Filter
module Formula = Formula

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
       ; Formula.to_nix Filter.to_nix enabled
       ; Formula.to_nix Constraint.to_nix constraints
       ])
;;

let nix_of_depends depends = Formula.to_nix nix_of_dependency depends

let nix_of_depopts depots = Formula.to_nix (nix_of_dependency ~optional:true) depots

let nix_of_depexts depexts =
  let open Nix in
  list
    (List.map
       (fun (packages, filter) ->
         attr_set
           [ ( "nativePackage"
             , list
                 (List.map
                    (fun package -> string (OpamSysPkg.to_string package))
                    (OpamSysPkg.Set.elements packages)) )
           ; "filter", Filter.to_nix filter
           ])
       depexts)
;;

let nix_of_args args =
  let open Nix in
  list
    (List.map
       (fun (arg, filter) ->
         let filter = Option.fold ~none:Filter.nix_of_true ~some:Filter.to_nix filter in
         let arg =
           match arg with
           | OpamTypes.CString str -> Env.nix_of_interpolated_string str
           | CIdent name -> Env.nix_of_ident_string name
         in
         attr_set [ "filter", filter; "arg", arg ])
       args)
;;

let nix_of_commands commands =
  let open Nix in
  list
    (List.map
       (fun (args, filter) ->
         let filter = Option.fold ~none:Filter.nix_of_true ~some:Filter.to_nix filter in
         attr_set [ "filter", filter; "args", nix_of_args args ])
       commands)
;;
