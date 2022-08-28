let nix_of_variable_scoped scope packages name defaults =
  let open Nix in
  let packages =
    List.map
      (function
         | Some package -> OpamPackage.Name.to_string package
         | None -> "_")
      packages
  in
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
    index scope "package"
    @@ [ attr_set
           [ "packageName", string package
           ; "name", string (OpamVariable.to_string name)
           ; "defaults", defaults
           ]
       ]
  in
  match packages with
  | [] -> resolve_local_var ()
  | [ package ] -> resolve_package_var package
  | packages -> index scope "combine" @@ [ list (List.map resolve_package_var packages) ]
;;

let nix_of_variable packages name defaults =
  Nix.scoped "__envScope" (fun scope ->
    nix_of_variable_scoped scope packages name defaults)
;;

let nix_of_ident_string_scoped scope name =
  let open Nix in
  let packages, name, defaults = OpamTypesBase.filter_ident_of_string name in
  index scope "toString" @@ [ nix_of_variable_scoped scope packages name defaults ]
;;

let nix_of_ident_string name =
  Nix.scoped "__envScope" (fun scope -> nix_of_ident_string_scoped scope name)
;;

let nix_of_interpolated_string input =
  let open Nix in
  scoped "__envScope" (fun scope ->
    let segments =
      Interpolated_string.parse
        ~on_string:(fun str -> StringSegment str)
        ~on_variable:(fun name -> CodeSegment (nix_of_ident_string_scoped scope name))
        input
    in
    MultilineString [ segments ])
;;
