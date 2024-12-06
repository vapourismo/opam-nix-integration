{
  description = "OPAM integration with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    opam-repository = {
      url = "github:ocaml/opam-repository";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    opam-repository,
  }:
    {
      overlays.ocamlBoot = import (self + /nix/boot/overlay.nix);

      overlays.default = import (self + /overlay.nix);
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };

        opamPackages = pkgs.opamPackages.overrideScope (final: prev: {
          repository = prev.repository.override {src = opam-repository;};
        });

        localOpamPackages = opamPackages.overrideScope (
          pkgs.lib.composeManyExtensions [
            (
              final: prev:
                prev.repository.select {
                  packageConstraints = [
                    "ocaml = 4.14.2"
                    "dune >= 3.4"
                    "ocaml-lsp-server"
                    "ocamlformat"
                    "utop"
                    "odoc"
                  ];

                  opams = [
                    {
                      name = "opam2nix";
                      src = self;
                    }
                  ];
                }
            )
            (final: prev: {
              ocamlformat-lib = prev.ocamlformat-lib.overrideAttrs (old: {
                propagatedBuildInputs = old.propagatedBuildInputs ++ [prev.ocp-indent];
              });
            })
          ]
        );
      in {
        packages = {
          default = self.packages.${system}.opam2nix;

          opam2nix = localOpamPackages.opam2nix;
        };

        inherit opamPackages;

        devShells.default = pkgs.mkShell {
          name = "opam-nix-integration-shell";

          packages =
            # OCaml packages
            (with localOpamPackages; [
              ocaml-lsp-server
              ocamlformat
              utop
              odoc
            ])
            ++
            # Misc utilities
            (with pkgs; [
              alejandra
              nil
            ])
            ++
            # Utilities for dune's watch mode
            (
              with pkgs;
                if stdenv.isDarwin
                then [fswatch]
                else [inotify-tools]
            );

          inputsFrom = [self.packages.${system}.opam2nix];
        };

        formatter = pkgs.alejandra;

        checks = {
          format = pkgs.runCommand "check-formatting" {buildInputs = [pkgs.alejandra];} ''
            alejandra -c ${self}
            touch $out
          '';
        };
      }
    );
}
