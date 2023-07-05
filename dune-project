(lang dune 2.9)

(generate_opam_files true)

(package
 (name opam2nix)
 (synopsis "Convert .opam files to Nix expressions")
 (depends opam-format (opam-state (< "2.2")) opam-0install cmdliner zarith ppx_deriving base64 hex))
