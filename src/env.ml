let convert_defaults =
  let open Nix in
  function
    | None -> null
    | Some (if_true, otherwise) ->
      attr_set [ "ifTrue", string if_true; "otherwise", string otherwise ]
;;

let lookup_var scope ?package name defaults =
  let open Nix in
  let packageAttrs =
    Option.fold ~none:[] ~some:(fun package -> [ "packageName", string package ]) package
  in
  apply
    (index scope "lookup")
    [ attr_set
        (packageAttrs
        @ [ "name", string (OpamVariable.to_string name)
          ; "defaults", convert_defaults defaults
          ])
    ]
;;

let nix_of_variable_scoped scope packages name defaults =
  let open Nix in
  let packages =
    List.map (Option.fold ~none:"_" ~some:OpamPackage.Name.to_string) packages
  in
  let resolve ?package () = lookup_var scope ?package name defaults in
  match packages with
  | [] -> resolve ()
  | [ package ] -> resolve ~package ()
  | packages ->
    apply
      (index scope "combine")
      [ list (List.map (fun package -> resolve ~package ()) packages) ]
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
        ~on_string:Str.str
        ~on_variable:(fun name -> Str.code (nix_of_ident_string_scoped scope name))
        input
    in
    of_str (Str.concat segments))
;;
