{
  description = "opam2nix";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    flake-utils.url = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
    with import nixpkgs { inherit system; };

    let
      ocamlPackages = ocaml-ng.ocamlPackages_4_13;
    in
    {
      devShell = mkShell {
        nativeBuildInputs = with ocamlPackages; [
          ocaml
          findlib
          dune_2
        ];

        buildInputs = with ocamlPackages; [
          ocaml-lsp
          ocamlformat
          opam-format
          ppxlib
          ppx_deriving
          cmdliner
        ];
      };
    }
  );
}
