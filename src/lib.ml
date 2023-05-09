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
  let name = Names.string_of_package_name name in
  lambda
    (Pat.ident "__dependencyScope")
    (apply
       (index scope "package")
       [ attr_set
           [ "name", string name
           ; "package", ident name
           ; "enabled", Formula.to_nix Filter.to_nix enabled
           ; "constraint", Formula.to_nix Constraint.to_nix constraints
           ]
       ])
;;

let nix_of_depends depends = Formula.to_nix nix_of_dependency depends

let nix_of_depopts depots = Formula.to_nix nix_of_dependency depots

module StringSet = Set.Make (String)

let nix_fields_of_deps depends depopts =
  let add_name set (name, _) = StringSet.add (Names.string_of_package_name name) set in
  let stage1 = OpamFormula.fold_left add_name StringSet.empty depopts in
  let stage2 = OpamFormula.fold_left add_name stage1 depends in
  StringSet.to_seq stage2
  |> List.of_seq
  |> List.map (fun name -> Nix.(Pat.field_opt name null))
;;

let nix_package_closure_of_deps depends depopts =
  let add_name set (name, _) = StringSet.add (Names.string_of_package_name name) set in
  let stage1 = OpamFormula.fold_left add_name StringSet.empty depopts in
  let stage2 = OpamFormula.fold_left add_name stage1 depends in
  StringSet.to_seq stage2
  |> List.of_seq
  |> List.map (fun name -> name, Nix.ident name)
  |> Nix.attr_set
;;

let nix_of_depexts depexts =
  let open Nix in
  depexts
  |> List.map (fun (packages, filter) ->
       attr_set
         [ ( "nativePackages"
           , list
               (List.map
                  (fun package -> index (ident "pkgs") (OpamSysPkg.to_string package))
                  (OpamSysPkg.Set.elements packages)) )
         ; "filter", Filter.to_nix filter
         ])
  |> list
;;

let nix_of_guessed_depexts depexts =
  let open Nix in
  depexts
  |> List.concat_map (fun (packages, _) ->
       List.map
         (fun package ->
           index ~default:null (ident "pkgs") (OpamSysPkg.to_string package))
         (OpamSysPkg.Set.elements packages))
  |> list
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

let hash_attrs hash =
  match OpamHash.kind hash with
  | `MD5 ->
    Some
      ( 0
      , "hash"
      , Nix.string
          ("md5-"
          ^ Base64.encode_string (Hex.to_string (`Hex (OpamHash.contents hash)))
          ^ "==") )
  | `SHA256 -> Some (1, "sha256", Nix.string (OpamHash.contents hash))
  | `SHA512 -> Some (2, "sha512", Nix.string (OpamHash.contents hash))
;;

let nix_of_url url =
  let open Nix in
  let checksum_attrs =
    List.filter_map hash_attrs (OpamFile.URL.checksum url)
    |> List.sort (fun (l, _, _) (r, _, _) -> Int.compare r l)
    |> function
      | (_, key, value) :: _ -> [ key, value ]
      | _ ->
        Printf.eprintf
          "No checksum provided for %s\n%!"
          (url |> OpamFile.URL.url |> OpamUrl.to_string);
        [] (* no checksum! *)
  in
  let url = OpamFile.URL.url url in
  match url.backend with
  | `git ->
    let rev_args =
      match url.hash with
      | Some ref -> [ "rev", string ref ]
      | None -> []
    in
    let url = { url with backend = `http; hash = None } in
    ident "fetchgit"
    @@ [ attr_set ([ "url", string (OpamUrl.to_string url) ] @ checksum_attrs @ rev_args)
       ]
  | _ ->
    let fetcher =
      match checksum_attrs with
      | [] ->
        (* The built-in fetchurl does not required checksums. *)
        "builtins.fetchurl"
      | _ -> "fetchurl"
    in
    ident fetcher
    @@ [ attr_set ([ "url", string (OpamUrl.to_string url) ] @ checksum_attrs) ]
;;
