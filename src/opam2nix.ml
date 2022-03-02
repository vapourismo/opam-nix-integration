let read_opam path = OpamFilename.of_string path |> OpamFile.make |> OpamFile.OPAM.read

let script env list =
  Filter.apply_to_list env list
  |> List.map (fun cmd ->
         Filter.apply_to_list env cmd
         |> List.map (fun arg -> Arg.resolve env arg)
         |> String.concat " ")
;;

let make_env extra_vars =
  let sys_vars =
    List.filter_map
      (fun (name, optValue) ->
        Lazy.force optValue
        |> Option.map (fun value -> OpamVariable.Full.global name, value))
      OpamSysPoll.variables
  in
  let default_vars =
    [ Var.global "os-distribution", Var.string "nixos"
    ; Var.global "make", Var.string "make"
    ; Var.foreign "ocaml" "preinstalled", Var.bool true
    ; Var.foreign "ocaml" "native", Var.bool true
    ]
  in
  Env.create (sys_vars @ default_vars @ extra_vars)
;;

module Options = struct
  open Cmdliner

  let req body infos = Arg.(opt (some body) None infos)

  type t =
    { name : string
    ; version : string
    ; file : string
    }

  let name_term = Arg.(info ~docv:"NAME" [ "n"; "name" ] |> req string |> required)

  let version_term =
    Arg.(info ~docv:"VERSION" [ "v"; "version" ] |> req string |> required)
  ;;

  let file_term = Arg.(info ~docv:"FILE" [ "f"; "file" ] |> req file |> required)

  let term =
    let combine name version file = { name; version; file } in
    Term.(const combine $ name_term $ version_term $ file_term)
  ;;
end

let hash_attrs hash =
  match OpamHash.kind hash with
  | `MD5 -> None
  | `SHA256 -> Some ("sha256", Nix.string (OpamHash.contents hash))
  | `SHA512 -> Some ("sha512", Nix.string (OpamHash.contents hash))
;;

let main options =
  let env =
    make_env
      [ Var.global "jobs", Var.int 1
      ; Var.self "name", Var.string options.Options.name
      ; Var.global "name", Var.string options.Options.name
      ; Var.self "version", Var.string options.Options.version
      ; Var.global "version", Var.string options.Options.version
      ; Var.global "with-test", Var.bool false
      ; Var.global "with-doc", Var.bool false
      ; Var.global "dev", Var.bool false
      ; Var.global "build", Var.bool true
      ]
  in
  let opam = read_opam options.Options.file in
  let build = script env opam.build in
  let install = script env opam.install in
  let source =
    Option.map
      (fun url ->
        let src = OpamFile.URL.url url |> OpamUrl.to_string in
        let check_attrs = List.filter_map hash_attrs (OpamFile.URL.checksum url) in
        let fetchurl =
          match check_attrs with
          | [] ->
            (* The built-in fetchurl does not required checksums. *)
            "builtins.fetchurl"
          | _ -> "fetchurl"
        in
        Nix.(ident fetchurl @@ [ attr_set ([ "url", string src ] @ check_attrs) ]))
      opam.url
  in
  let depends_exp = Depends.transform_depends opam.depends in
  let dependency_names = Depends.all opam.depends in
  let native_depends =
    opam.depexts
    |> List.map (fun (set, filter) -> set, Some filter)
    |> Filter.apply_to_list env
    |> List.fold_left OpamSysPkg.Set.union OpamSysPkg.Set.empty
    |> OpamSysPkg.Set.elements
    |> List.map OpamSysPkg.to_string
  in
  let extra_files =
    Option.fold
      ~none:[]
      ~some:(fun files ->
        List.map
          (fun (name, hash) ->
            Nix.(
              ident "resolveExtraFile"
              @@ [ attr_set
                     ([ "path", string (OpamFilename.Base.to_string name) ]
                     @ Option.fold ~none:[] ~some:(fun hash -> [ hash ]) (hash_attrs hash)
                     )
                 ]))
          files)
      opam.extra_files
  in
  let expr =
    Nix.(
      Pattern.attr_set
        ([ "mkOpam2NixPackage"; "fetchurl"; "resolveExtraFile" ]
        @ dependency_names
        @ native_depends)
      => ident "mkOpam2NixPackage"
         @@ [ attr_set
                ([ "name", string options.name
                 ; "version", string options.version
                 ; "buildScript", multiline build
                 ; "installScript", multiline install
                 ; "depends", depends_exp
                 ; "nativeDepends", list (List.map ident native_depends)
                 ; "extraFiles", list extra_files
                 ]
                @ Option.fold ~none:[] ~some:(fun src -> [ "src", src ]) source)
            ])
  in
  print_endline (Nix.render expr)
;;

let () =
  let open Cmdliner.Term in
  (const main $ Options.term, info "opam2nix") |> eval |> exit
;;
