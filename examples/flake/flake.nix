{
  description = "Example Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    opam-nix-integration.url = "github:vapourismo/opam-nix-integration";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    opam-nix-integration,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        packageSet = opam-nix-integration.opamPackages.${system}.overrideScope' (
          pkgs.lib.composeManyExtensions [
            (final: prev:
              prev.repository.select {
                packageConstraints = [
                  "ocaml = 4.14.1"
                ];

                opams = [
                  {
                    name = "opam2nix";
                    opam = ../../opam2nix.opam;
                  }
                ];
              })
          ]
        );
      in {
        packages = {
          opam2nix =
            packageSet.callOpam2Nix
            {
              name = "opam2nix";
              version = "0.0.0";
              src = opam-nix-integration;
            }
            {};
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
      }
    );
}
