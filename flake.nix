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
      defaultPackage = ocamlPackages.buildDunePackage {
        pname = "opam2nix";
        version = "0.0.0";

        useDune2 = true;

        src = self;

        propagatedBuildInputs = with ocamlPackages; [
          opam-format
          ppxlib
          ppx_deriving
          cmdliner
          zarith
        ];
      };

      devShell = mkShell {
        nativeBuildInputs = with ocamlPackages; [
          ocaml
          findlib
          dune_2
        ];

        buildInputs = with ocamlPackages; [
          ocaml-lsp
          ocamlformat
        ] ++ self.defaultPackage.${system}.propagatedBuildInputs;
      };
    }
  );
}
