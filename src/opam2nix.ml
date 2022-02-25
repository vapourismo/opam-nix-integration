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
    ; Var.global "os_distribution", Var.string "nixos"
    ; Var.global "arch", Var.string "x86_64"
    ; Var.global "make", Var.string "make"
    ; Var.global "prefix", Var.string "$out"
    ; Var.self "lib", Var.string "$out/lib"
    ; Var.self "bin", Var.string "$out/bin"
    ; Var.self "doc", Var.string "$out/share/doc"
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
  let expr =
    Nix.(
      lambda
        (Pattern.attr_set [ "mkDerivation" ])
        (apply
           (ident "mkDerivation")
           [ attr_set
               [ "pname", string options.name
               ; "version", string options.version
               ; "buildPhase", multiline build
               ; "installPhase", multiline install
               ; "phases", list [ string "buildPhase"; string "installPhase" ]
               ]
           ]))
  in
  print_endline (Nix.render expr)
;;

let () =
  let open Cmdliner.Term in
  (const main $ Options.term, info "opam2nix") |> eval |> exit
;;
