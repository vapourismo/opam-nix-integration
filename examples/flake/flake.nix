{
  description = "Example Flake";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    flake-utils.url = github:numtide/flake-utils;
    opam-nix-integration.url = github:vapourismo/opam-nix-integration;
  };

  outputs = { self, nixpkgs, flake-utils, opam-nix-integration }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        packageSet = opam-nix-integration.opamPackages.${system}.overrideScope' (
          pkgs.lib.composeManyExtensions [
            (final: prev: prev.repository.select {
              packageConstraints = [
                "ocaml = 4.14.1"
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
            })
            (final: prev: {
              nix =
                final.callOpam2Nix
                  {
                    name = "nix";
                    version = "0.0.0";
                    src = opam-nix-integration;
                  }
                  { };
            })
          ]
        );
      in
      {
        packages = {
          opam2nix =
            packageSet.callOpam2Nix
              {
                name = "opam2nix";
                version = "0.0.0";
                src = opam-nix-integration;
              }
              { };

          opamsubst2nix =
            packageSet.callOpam2Nix
              {
                name = "opamsubst2nix";
                version = "0.0.0";
                src = opam-nix-integration;
              }
              { };

          opamvars2nix =
            packageSet.callOpam2Nix
              {
                name = "opamvars2nix";
                version = "0.0.0";
                src = opam-nix-integration;
              }
              { };

          opam0install2nix =
            packageSet.callOpam2Nix
              {
                name = "opam0install2nix";
                version = "0.0.0";
                src = opam-nix-integration;
              }
              { };
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
