let cli =
  let open Cmdliner in
  let open Cmd in
  group
    (info "opam2nix")
    [ v (info "generate-derivation") Generate_derivation_command.command
    ; v (info "solve-0install") Solve_0install_command.command
    ; v (info "opam-variables") Opam_variables_command.command
    ; v (info "substitute") Substitute_command.command
    ]
;;

let () = Stdlib.exit (Cmdliner.Cmd.eval cli)
