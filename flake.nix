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

  outputs = { self, nixpkgs, flake-utils, flake-compat }: flake-utils.lib.eachDefaultSystem (system:
    with import nixpkgs { inherit system; };

    let
      ocamlPackages = ocaml-ng.ocamlPackages_4_13;
    in
    {
      defaultPackage = self.packages.${system}.opam2nix;

      packages = {
        opam2nix = ocamlPackages.buildDunePackage {
          pname = "opam2nix";
          version = "0.0.0";

          useDune2 = true;

          src = self;

          buildInputs = with ocamlPackages; [
            opam-format
            opam-state
            ppxlib
            ppx_deriving
            cmdliner
            zarith
          ];
        };

        opamvars2nix = ocamlPackages.buildDunePackage {
          pname = "opamvars2nix";
          version = "0.0.0";

          useDune2 = true;

          src = self;

          buildInputs = with ocamlPackages; [
            opam-format
            opam-state
            zarith
          ];
        };

        opamsubst2nix = ocamlPackages.buildDunePackage {
          pname = "opamsubst2nix";
          version = "0.0.0";

          useDune2 = true;

          src = self;

          buildInputs = with ocamlPackages; [
            opam-format
            zarith
          ];
        };
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

        buildInputs = self.defaultPackage.${system}.buildInputs;
      };
    }
  );
}
