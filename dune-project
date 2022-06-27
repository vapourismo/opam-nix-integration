(lang dune 2.9)

(generate_opam_files true)

(package
 (name opam2nix)
 (synopsis "Convert .opam files to Nix expressions")
 (depends opam-format opam-state cmdliner zarith ppx_deriving base64 hex))

(package
 (name opamvars2nix)
 (synopsis "Express OPAM system-level variables as Nix expression")
 (depends opam-format opam-state zarith base64 hex))

(package
 (name opamsubst2nix)
 (synopsis "Convert interpolation target files to Nix expressions")
 (depends opam-format zarith base64 hex))

(package
 (name opam0install2nix)
 (synopsis "Solve package constraints as Nix expressions")
 (depends opam-format opam-0install cmdliner zarith base64 hex))
