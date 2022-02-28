let read_opam path = OpamFilename.of_string path |> OpamFile.make |> OpamFile.OPAM.read

let script env list =
  Filter.apply_to_list env list
  |> List.map (fun cmd ->
         Filter.apply_to_list env cmd
         |> List.map (fun arg -> Arg.resolve env arg)
         |> String.concat " ")
;;

let default_env =
  let sys_vars =
    List.filter_map
      (fun (name, optValue) ->
        Lazy.force optValue
        |> Option.map (fun value -> OpamVariable.Full.global name, value))
      OpamSysPoll.variables
  in
  let default_vars =
    [ Var.global "make", Var.string "make"
    ; Var.global "prefix", Var.string "$out"
    ; Var.self "lib", Var.string "$out/lib"
    ; Var.global "lib", Var.string "$out/lib"
    ; Var.self "bin", Var.string "$out/bin"
    ; Var.global "bin", Var.string "$out/bin"
    ; Var.self "doc", Var.string "$out/share/doc"
    ; Var.global "doc", Var.string "$out/share/doc"
    ; Var.self "man", Var.string "$out/share/man"
    ; Var.global "man", Var.string "$out/share/man"
    ; Var.foreign "ocaml" "preinstalled", Var.bool true
    ; Var.foreign "ocaml" "native", Var.bool true
    ]
  in
  Env.create (sys_vars @ default_vars)
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
  let opam = read_opam options.Options.file in
  let build = script default_env opam.build in
  let install = script default_env opam.install in
  let source =
    Option.map
      (fun url ->
        let src = OpamFile.URL.url url |> OpamUrl.to_string in
        let check_attrs = List.filter_map hash_attrs (OpamFile.URL.checksum url) in
        Nix.(ident "fetchurl" @@ [ attr_set ([ "url", string src ] @ check_attrs) ]))
      opam.url
  in
  let depends =
    opam.depends
    |> OpamFormula.map (fun (name, _formula) ->
           OpamFormula.Atom (name, OpamFormula.Empty))
    |> OpamFormula.atoms
    |> List.map OpamFormula.string_of_atom
  in
  let native_depends =
    opam.depexts
    |> List.map (fun (set, filter) -> set, Some filter)
    |> Filter.apply_to_list default_env
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
        @ depends
        @ native_depends)
      => ident "mkOpam2NixPackage"
         @@ [ attr_set
                ([ "name", string options.name
                 ; "version", string options.version
                 ; "buildScript", multiline build
                 ; "installScript", multiline install
                 ; "depends", list (List.map ident depends)
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
