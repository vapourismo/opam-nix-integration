(lang dune 2.9)

(generate_opam_files true)

(package
 (name opam2nix)
 (synopsis "Opam file converted")
 (description "Convert .opam files to .nix expressions.")
 (depends opam-format opam-state cmdliner zarith ppx_deriving))

(package
 (name opamvars2nix)
 (synopsis "Nix OPAM variable utility")
 (description "Print OPAM variables as Nix expressions")
 (depends opam-format opam-state))
