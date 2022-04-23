module Lib = Opam2nix_lib

let read_opam path = OpamFilename.of_string path |> OpamFile.make |> OpamFile.OPAM.read

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
  let extra_files =
    Option.fold
      ~none:[]
      ~some:(fun files ->
        match files with
        | [] -> []
        | files ->
          List.map
            (fun (path, _hash) ->
              let path = OpamFilename.Base.to_string path in
              attr_set
                [ "path", string path
                ; "src", ident "resolveOpamExtraSrc" @@ [ ident "extraSrc"; string path ]
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
  let expr =
    Pattern.attr_set
      [ "mkOpamDerivation"
      ; "selectOpamSrc"
      ; "resolveOpamExtraSrc"
      ; "fetchurl"
      ; "altSrc ? null"
      ; "extraSrc ? null"
      ; "jobs ? 1"
      ; "with-test ? false"
      ; "with-doc ? false"
      ]
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
               ; "extraFiles", list (extra_files @ extra_sources)
               ; "substFiles", list substs
               ; "patches", list patches
               ; "jobs", ident "jobs"
               ; "with-test", ident "with-test"
               ; "with-doc", ident "with-doc"
               ]
              @
              match source with
              | Some src -> [ "src", ident "selectOpamSrc" @@ [ src; ident "altSrc" ] ]
              | None -> [ "src", ident "altSrc" ])
          ]
  in
  print_endline (render expr)
;;

let () =
  let open Cmdliner.Term in
  (const main $ Options.term, info "opam2nix") |> eval |> exit
;;
