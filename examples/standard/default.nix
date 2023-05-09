{nixpkgs ? fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz"}: let
  opam-repository = fetchTarball "https://github.com/ocaml/opam-repository/archive/refs/heads/master.tar.gz";

  opam-nix-integration = import ../..;

  pkgs = import nixpkgs {overlays = [opam-nix-integration.overlay];};

  scope = pkgs.opamPackages.overrideScope' (pkgs.lib.composeManyExtensions [
    (final: prev: {
      repository = prev.repository.override {src = opam-repository;};
    })
    (final: prev:
      prev.repository.select {
        packageConstraints = [
          "ocaml = 4.14.1"
        ];

        opams = [
          {
            name = "opam2nix";
            src = ../..;
          }
        ];
      })
    (final: prev: {
      ocaml-base-compiler = prev.ocaml-base-compiler.override {
        jobs = "$NIX_BUILD_CORES";
      };
    })
  ]);
in
  pkgs.lib.filterAttrs (_: v: pkgs.lib.isDerivation v) scope
