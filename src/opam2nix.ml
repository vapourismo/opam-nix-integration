let read_opam path = OpamFilename.of_string path |> OpamFile.make |> OpamFile.OPAM.read

let script env list =
  Filter.apply_to_list env list
  |> List.map (fun cmd ->
         Filter.apply_to_list env cmd
         |> List.map (fun arg -> Arg.resolve env arg)
         |> String.concat " ")
;;

let default_env =
  Env.create
    [ Var.global "os", Var.string "linux"
    ; Var.global "os-distribution", Var.string "nixos"
    ; Var.global "arch", Var.string "x86_64"
    ; Var.global "make", Var.string "make"
    ; Var.global "prefix", Var.string "$out"
    ; Var.self "lib", Var.string "$out/lib"
    ; Var.global "lib", Var.string "$out/lib"
    ; Var.self "bin", Var.string "$out/bin"
    ; Var.global "bin", Var.string "$out/bin"
    ; Var.self "doc", Var.string "$out/share/doc"
    ; Var.global "doc", Var.string "$out/share/doc"
    ; Var.self "man", Var.string "$out/share/man"
    ; Var.global "man", Var.string "$out/share/man"
    ]
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

let main options =
  let opam = read_opam options.Options.file in
  let build = script default_env opam.build in
  let install = script default_env opam.install in
  let source =
    Option.map
      (fun url ->
        let src = OpamFile.URL.url url |> OpamUrl.to_string in
        let check_attrs =
          List.filter_map
            (fun hash ->
              match OpamHash.kind hash with
              | `MD5 -> None
              | `SHA256 -> Some ("sha256", Nix.string (OpamHash.contents hash))
              | `SHA512 -> Some ("sha512", Nix.string (OpamHash.contents hash)))
            (OpamFile.URL.checksum url)
        in
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
  let expr =
    Nix.(
      Pattern.attr_set ([ "mkDerivation"; "fetchurl" ] @ depends @ native_depends)
      => ident "mkDerivation"
         @@ [ attr_set
                ([ "pname", string options.name
                 ; "version", string options.version
                 ; "buildPhase", multiline build
                 ; "installPhase", multiline install
                 ; ( "phases"
                   , list
                       (List.filter
                          (fun _ -> Option.is_some source)
                          [ string "unpackPhase" ]
                       @ [ string "buildPhase"; string "installPhase" ]) )
                 ; "propagatedBuildInputs", list (List.map ident depends)
                 ; "nativeBuildInputs", list (List.map ident native_depends)
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
