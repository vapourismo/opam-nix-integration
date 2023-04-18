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
            name = "nix";
            opam = ../../nix.opam;
          }
          {
            name = "opam2nix";
            opam = ../../opam2nix.opam;
          }
          {
            name = "opamsubst2nix";
            opam = ../../opamsubst2nix.opam;
          }
          {
            name = "opamvars2nix";
            opam = ../../opamvars2nix.opam;
          }
          {
            name = "opam0install2nix";
            opam = ../../opam0install2nix.opam;
          }
        ];
      })
    (final: prev: {
      ocaml-base-compiler = prev.ocaml-base-compiler.override {
        jobs = "$NIX_BUILD_CORES";
      };

      nix =
        final.callOpam2Nix
        {
          name = "nix";
          version = "0.0.0";
          src = ../..;
        }
        {};

      opam2nix =
        final.callOpam2Nix
        {
          name = "opam2nix";
          version = "0.0.0";
          src = ../..;
        }
        {};

      opamsubst2nix =
        final.callOpam2Nix
        {
          name = "opamsubst2nix";
          version = "0.0.0";
          src = ../..;
        }
        {};

      opamvars2nix =
        final.callOpam2Nix
        {
          name = "opamvars2nix";
          version = "0.0.0";
          src = ../..;
        }
        {};

      opam0install2nix =
        final.callOpam2Nix
        {
          name = "opam0install2nix";
          version = "0.0.0";
          src = ../..;
        }
        {};
    })
  ]);
in
  pkgs.lib.filterAttrs (_: v: pkgs.lib.isDerivation v) scope
