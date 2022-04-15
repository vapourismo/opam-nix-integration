{
  description = "opam2nix";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    flake-utils.url = github:numtide/flake-utils;
    flake-compat = {
      url = github:edolstra/flake-compat;
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat }:
    {
      overlay = import (self + /nix/packages/ocaml/overlay.nix);
    }
    // flake-utils.lib.eachDefaultSystem (system:
      with import nixpkgs { inherit system; };

      let
        ocamlPackages = ocaml-ng.ocamlPackages_4_13.overrideScope' self.overlay;

      in
      {
        defaultPackage = self.packages.${system}.opam2nix;

        packages = {
          opam2nix = ocamlPackages.opam2nix;

          opamvars2nix = ocamlPackages.opamvars2nix;

          opamsubst2nix = ocamlPackages.opamsubst2nix;

          opam0install2nix = ocamlPackages.opam0install2nix;
        };

        devShell = mkShell {
          nativeBuildInputs = with ocamlPackages; [
            ocaml
            ocaml-lsp
            ocamlformat
            findlib
            dune_2
            utop
            nixpkgs-fmt
            odoc
            inotify-tools
            rnix-lsp
          ];

          buildInputs =
            builtins.concatMap
              (pkg: pkg.buildInputs)
              (builtins.attrValues self.packages.${system});
        };
      }
    );
}
