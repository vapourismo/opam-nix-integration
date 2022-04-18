{
  description = "Example Flake";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    flake-utils.url = github:numtide/flake-utils;
    opam-repository = {
      url = github:ocaml/opam-repository;
      flake = false;
    };
    opam-nix-integration.url = path:../..;
  };

  outputs = { self, nixpkgs, flake-utils, opam-repository, opam-nix-integration }:
    {
      overlay = final: prev:
        let
          defaultScope = prev.ocamlPackages.callPackage opam-nix-integration {
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
        in
        {
          opamNixIntegrationPackages = defaultScope.overrideScope' (final: prev: {
            ocaml-base-compiler = prev.ocaml-base-compiler.override { jobs = 4; };

            opam2nix =
              final.callOpam2Nix
                {
                  name = "opam2nix";
                  version = "0.0.0";
                  src = opam-nix-integration;
                }
                { };

            opamsubst2nix =
              final.callOpam2Nix
                {
                  name = "opamsubst2nix";
                  version = "0.0.0";
                  src = opam-nix-integration;
                }
                { };

            opamvars2nix =
              final.callOpam2Nix
                {
                  name = "opamvars2nix";
                  version = "0.0.0";
                  src = opam-nix-integration;
                }
                { };

            opam0install2nix =
              final.callOpam2Nix
                {
                  name = "opam0install2nix";
                  version = "0.0.0";
                  src = opam-nix-integration;
                }
                { };
          });

          inherit (final.opamNixIntegrationPackages)
            opam2nix opamsubst2nix opamvars2nix opam0install2nix;
        };
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        };
      in
      {
        packages = {
          inherit (pkgs) opam2nix opamsubst2nix opamvars2nix opam0install2nix;
        };

        defaultPackage = pkgs.stdenv.mkDerivation {
          name = "opam-nix-integration";

          buildInputs = builtins.attrValues self.packages.${system};

          dontUnpack = true;
          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            mkdir -p $out/bin
            for pkg in $buildInputs; do
              cp $pkg/bin/* $out/bin
            done
          '';
        };
      });
}
