module Lib = Opam2nix_lib

let read_opam path = OpamFilename.of_string path |> OpamFile.make |> OpamFile.OPAM.read

module Options = struct
  open Cmdliner

  let req body infos = Arg.(opt (some body) None infos)

  type t =
    { name : string
    ; version : string
    ; file : string
    ; source : string option
    ; extra_source : string option
    }

  let name_term = Arg.(info ~docv:"NAME" [ "n"; "name" ] |> req string |> required)

  let version_term =
    Arg.(info ~docv:"VERSION" [ "v"; "version" ] |> req string |> required)
  ;;

  let file_term = Arg.(info ~docv:"FILE" [ "f"; "file" ] |> req file |> required)

  let source_term = Arg.(info ~docv:"PATH" [ "s"; "source" ] |> req file |> value)

  let extra_source_term =
    Arg.(info ~docv:"PATH" [ "e"; "extra-source" ] |> req string |> value)
  ;;

  let term =
    let combine name version file source extra_source =
      { name; version; file; source; extra_source }
    in
    Term.(
      const combine
      $ name_term
      $ version_term
      $ file_term
      $ source_term
      $ extra_source_term)
  ;;
end

let hash_attrs hash =
  match OpamHash.kind hash with
  | `MD5 -> None
  | `SHA256 -> Some ("sha256", Nix.string (OpamHash.contents hash))
  | `SHA512 -> Some ("sha512", Nix.string (OpamHash.contents hash))
;;

let main options =
  let opam = read_opam options.Options.file in
  let build = Lib.nix_of_commands opam.build in
  let install = Lib.nix_of_commands opam.install in
  let test = Lib.nix_of_commands opam.run_test in
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
  let depends = Lib.nix_of_depends opam.depends in
  let depopts = Lib.nix_of_depopts opam.depopts in
  let native_depends = Lib.nix_of_depexts opam.depexts in
  let extra_files =
    Option.fold
      ~none:[]
      ~some:(fun files ->
        match files, options.extra_source with
        | [], _ -> []
        | files, Some extra_source ->
          List.map
            (fun (name, _hash) ->
              let open Nix in
              let name = OpamFilename.Base.to_string name in
              attr_set
                [ "path", string name; "src", ident (Filename.concat extra_source name) ])
            files
        | _, None ->
          failwith "Got extra files from Opam, but no --extra-source flag was provided!")
      opam.extra_files
  in
  let substs =
    List.map (fun path -> OpamFilename.Base.to_string path |> Nix.string) opam.substs
  in
  let expr =
    Nix.(
      Pattern.attr_set
        [ "mkOpamDerivation"
        ; "fetchurl"
        ; "jobs ? 1"
        ; "enableTests ? false"
        ; "enableDocs ? false"
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
                 ; "extraFiles", list extra_files
                 ; "substFiles", list substs
                 ; "jobs", ident "jobs"
                 ; "enableTests", ident "enableTests"
                 ; "enableDocs", ident "enableDocs"
                 ]
                @
                match source, options.source with
                | Some src, _ -> [ "src", src ]
                | None, Some src -> [ "src", ident src ]
                | _, _ -> [])
            ])
  in
  print_endline (Nix.render expr)
;;

let () =
  let open Cmdliner.Term in
  (const main $ Options.term, info "opam2nix") |> eval |> exit
;;
