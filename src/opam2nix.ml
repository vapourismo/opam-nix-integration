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
    ; Var.self "doc", Var.string "$out/share/doc"
    ]
;;

let () =
  let opam = read_opam "./cmdliner.opam" in
  script default_env opam.build |> List.iter print_endline;
  script default_env opam.install |> List.iter print_endline
;;
