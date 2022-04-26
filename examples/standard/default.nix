let
  opam-repository = pkgs.fetchFromGitHub {
    owner = "ocaml";
    repo = "opam-repository";
    rev = "5269af290fff3fc631a8855e4255b4b53713b467";
    sha256 = "sha256-6sFe1838OthFRUhJQ74u/k0urk7Om/gSNnX67BE+DJs=";
  };

  opam-nix-integration = import ../..;

  pkgs =
    import
      (fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz")
      { overlays = [ opam-nix-integration.overlay ]; };

  defaultScope = pkgs.opam-nix-integration.makePackageSet {
    repository = opam-repository;

    packageSelection = {
      packageConstraints = [
        "ocaml = 4.13.1"
        "dune < 3"
        "zarith"
        "opam-format"
        "opam-state"
        "opam-0install"
        "cmdliner"
        "ppx_deriving"
      ];
    };
  };

  finalScope = defaultScope.overrideScope' (final: prev: {
    ocaml-base-compiler = prev.ocaml-base-compiler.override { jobs = 4; };

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
