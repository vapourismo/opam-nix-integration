let
  pkgs =
    import
      (fetchTarball
        "https://github.com/NixOS/nixpkgs/archive/759a1f7742c76594955b8fc1c04b66dc409b8ff2.tar.gz")
      { };

  defaultScope = pkgs.ocamlPackages.callPackage ../.. {
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
