(lang dune 2.9)

(generate_opam_files true)

(package
 (name opam2nix)
 (synopsis "Opam file converted")
 (description "Convert .opam files to .nix expressions.")
 (depends opam-format cmdliner zarith ppx_deriving))
