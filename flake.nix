{
  description = "OPAM integration with Nix";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    flake-utils.url = github:numtide/flake-utils;
    opam-repository = {
      url = github:ocaml/opam-repository;
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, opam-repository }:
    {
      overlays.ocamlBool = import (self + /nix/packages/ocaml/overlay.nix);
    }
    // flake-utils.lib.eachDefaultSystem (system:
      with import nixpkgs { inherit system; };

      let
        ocamlPackages = ocaml-ng.ocamlPackages_4_13.overrideScope' self.overlays.ocamlBool;
      in

      {
        defaultPackage = self.packages.${system}.opam2nix;

        packages = {
          opam2nix = ocamlPackages.opam2nix;

          opamvars2nix = ocamlPackages.opamvars2nix;

          opamsubst2nix = ocamlPackages.opamsubst2nix;

          opam0install2nix = ocamlPackages.opam0install2nix;

          emptyScope = ocamlPackages.callPackage (self + /nix/scope/opam-repository) {
            repository = opam-repository;
          };
        };

        devShell = mkShell {
          nativeBuildInputs = with ocamlPackages; [
            ocaml-lsp
            ocamlformat
            utop
            nixpkgs-fmt
            odoc
            inotify-tools
            rnix-lsp
          ];

          buildInputs =
            builtins.concatMap
              (name:
                let pkg = self.packages.${system}.${name}; in
                pkg.buildInputs
                ++ pkg.propagatedBuildInputs
                ++ pkg.nativeBuildInputs
                ++ pkg.propagatedNativeBuildInputs)
              [ "opam2nix" "opamvars2nix" "opamsubst2nix" "opam0install2nix" ];
        };
      }
    );
}
