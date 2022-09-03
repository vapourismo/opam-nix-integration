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
      overlays.ocamlBoot = import (self + /nix/boot/overlay.nix);

      overlay = import (self + /overlay.nix);
    }
    // flake-utils.lib.eachDefaultSystem (system:
      with import nixpkgs
        {
          inherit system;
          overlays = [ self.overlay ];
        };

      let
        ocamlPackages = ocaml-ng.ocamlPackages_4_14.overrideScope' self.overlays.ocamlBoot;
      in

      {
        defaultPackage = self.packages.${system}.opam2nix;

        packages = {
          opam2nix = ocamlPackages.opam2nix;

          opamvars2nix = ocamlPackages.opamvars2nix;

          opamsubst2nix = ocamlPackages.opamsubst2nix;

          opam0install2nix = ocamlPackages.opam0install2nix;

          makePackageSet = { packageSelection ? { }, overlays ? [ ] }:
            opam-nix-integration.makePackageSet {
              repository = opam-repository;
              inherit packageSelection overlays;
            };
        };

        devShell = mkShell {
          name = "opam-nix-integration-shell";

          packages =
            # OCaml packages
            (with ocamlPackages; [
              ocaml-lsp
              ocamlformat
              utop
              nixpkgs-fmt
              odoc
              rnix-lsp
            ])
            ++
            # Utilities  for dune's watch mode
            (
              if stdenv.isDarwin then
                [ fswatch ]
              else
                [ inotify-tools ]
            );

          inputsFrom = with self.packages.${system}; [
            opam2nix
            opamvars2nix
            opamsubst2nix
            opam0install2nix
          ];
        };
      }
    );
}
