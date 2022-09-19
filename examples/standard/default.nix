{ nixpkgs ? fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz" }:

let
  opam-repository = pkgs.fetchFromGitHub {
    owner = "ocaml";
    repo = "opam-repository";
    rev = "f904585098b809001380caada4b7426c112d086c";
    sha256 = "sha256-oARmpd4j8IOvLzC8RqZ8MBDzAvTjI1BdeUbEL59T99A=[]";
  };

  opam-nix-integration = import ../..;

  pkgs = import nixpkgs { overlays = [ opam-nix-integration.overlay ]; };

  defaultScope = pkgs.opam-nix-integration.makePackageSet {
    repository = opam-repository;

    packageSelection = {
      packageConstraints = [
        "ocaml = 4.14.0"
        "dune >= 3.4"
        "zarith"
        "opam-format"
        "opam-state"
        "opam-0install"
        "cmdliner"
        "ppx_deriving"
        "base64"
        "hex"
      ];
    };

    overlays = [
      (final: prev: {
        nix =
          final.callOpam2Nix
            {
              name = "nix";
              version = "0.0.0";
              src = ../..;
            }
            { };
      })
    ];
  };

  finalScope = defaultScope.overrideScope' (final: prev: {
    ocaml-base-compiler = prev.ocaml-base-compiler.override { jobs = "$NIX_BUILD_CORES"; };

    opam2nix =
      final.callOpam2Nix
        {
          name = "opam2nix";
          version = "0.0.0";
          src = ../..;
        }
        { };

    opamsubst2nix =
      final.callOpam2Nix
        {
          name = "opamsubst2nix";
          version = "0.0.0";
          src = ../..;
        }
        { };

    opamvars2nix =
      final.callOpam2Nix
        {
          name = "opamvars2nix";
          version = "0.0.0";
          src = ../..;
        }
        { };

    opam0install2nix =
      final.callOpam2Nix
        {
          name = "opam0install2nix";
          version = "0.0.0";
          src = ../..;
        }
        { };
  });
in

finalScope
