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
  let substs =
    List.map (fun path -> OpamFilename.Base.to_string path |> Nix.string) opam.substs
  in
  let expr =
    Nix.(
      Pattern.attr_set [ "mkOpam2NixPackage"; "fetchurl"; "resolveExtraFile" ]
      => ident "mkOpam2NixPackage"
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
