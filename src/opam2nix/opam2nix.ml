module Lib = Opam2nix_lib

let read_opam path = path |> OpamFile.make |> OpamFile.OPAM.read

module Options = struct
  open Cmdliner

  let req body infos = Arg.(opt (some body) None infos)

  type t =
    { name : string
    ; version : string
    ; file : OpamFilename.t
    ; extra_files : OpamFilename.Dir.t option
    }

  let name_term = Arg.(info ~docv:"NAME" [ "n"; "name" ] |> req string |> required)

  let version_term =
    Arg.(info ~docv:"VERSION" [ "v"; "version" ] |> req string |> required)
  ;;

  let file_term = Arg.(info ~docv:"FILE" [ "f"; "file" ] |> req file |> required)

  let extra_files_term =
    Arg.(info ~docv:"DIR" [ "e"; "extra-files" ] |> req file |> value)
  ;;

  let term =
    let combine name version file extra_files =
      { name
      ; version
      ; file = OpamFilename.of_string file
      ; extra_files = Option.map OpamFilename.Dir.of_string extra_files
      }
    in
    Term.(const combine $ name_term $ version_term $ file_term $ extra_files_term)
  ;;
end

let main options =
  let open Nix in
  let opam = read_opam options.Options.file in
  let build = Lib.nix_of_commands opam.build in
  let install = Lib.nix_of_commands opam.install in
  let test = Lib.nix_of_commands opam.run_test in
  let source = Option.map Lib.nix_of_url opam.url in
  let depends = Lib.nix_of_depends opam.depends in
  let depopts = Lib.nix_of_depopts opam.depopts in
  let native_depends = Lib.nix_of_depexts opam.depexts in
  let guessed_native_depends = Lib.nix_of_guessed_depexts opam.depexts in
  let extra_files_dir =
    match options.extra_files with
    | Some extra_files -> extra_files
    | None -> OpamFilename.concat_and_resolve (OpamFilename.dirname options.file) "files"
  in
  let extra_files =
    Option.fold
      ~none:[]
      ~some:(fun files ->
        match files with
        | [] -> []
        | files ->
          List.map
            (fun (path, _hash) ->
              let path_str = OpamFilename.Base.to_string path in
              attr_set
                [ "path", string path_str
                ; ( "src"
                  , let path =
                      OpamFilename.create extra_files_dir path
                      |> OpamFilename.to_string
                      |> string
                    in
                    (* Raw paths literals in Nix expressions might not parse correctly. Therefore we
                       must pass it as a string and convert it to a path in the expression. *)
                    infix (ident "/.") "+" (apply (ident "builtins.toPath") [ path ]) )
                ])
            files)
      opam.extra_files
  in
  let extra_sources =
    List.map
      (fun (path, url) ->
        let name = OpamFilename.Base.to_string path in
        attr_set [ "path", string name; "src", Lib.nix_of_url url ])
      opam.extra_sources
  in
  let substs =
    List.map (fun path -> OpamFilename.Base.to_string path |> string) opam.substs
  in
  let patches =
    List.map
      (fun (path, filter) ->
        attr_set
          [ "path", string (OpamFilename.Base.to_string path)
          ; ( "filter"
            , Option.fold ~none:Lib.Filter.nix_of_true ~some:Lib.Filter.to_nix filter )
          ])
      opam.patches
  in
  let extra_pattern_fields = Lib.nix_fields_of_deps opam.depends opam.depopts in
  let subst_env = Lib.nix_package_closure_of_deps opam.depends opam.depopts in
  let expr =
    Pat.(
      attr_set
        ([ field "pkgs"
         ; field "mkOpamDerivation"
         ; field "fetchurl"
         ; field "fetchgit"
         ; field "altSrc" @? null
         ; field "jobs" @? int 1
         ; field "with-test" @? bool false
         ; field "with-doc" @? bool false
         ]
        @ extra_pattern_fields))
    => ident "mkOpamDerivation"
       @@ [ attr_set
              ([ "name", string options.name
               ; "version", string options.version
               ; "buildScript", build
               ; "installScript", install
               ; "testScript", test
               ; "depends", depends
               ; "optionalDepends", depopts
               ; "nativeDepends", native_depends
               ; "guessedNativeDepends", guessed_native_depends
               ; "extraFiles", list (extra_files @ extra_sources)
               ; "substFiles", list substs
               ; "substEnv", subst_env
               ; "patches", list patches
               ; "jobs", ident "jobs"
               ; "with-test", ident "with-test"
               ; "with-doc", ident "with-doc"
               ]
              @
              match source with
              | Some src ->
                [ "src", if_ (infix (ident "altSrc") "!=" null) (ident "altSrc") src ]
              | None -> [ "src", ident "altSrc" ])
          ]
  in
  print_endline (render expr)
;;

let () =
  let open Cmdliner in
  Cmd.v (Cmd.info "opam2nix") Term.(const main $ Options.term) |> Cmd.eval |> Stdlib.exit
;;
