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

      zeroinstall-solver = ocamlPackages.buildDunePackage {
        pname = "0install-solver";
        version = "2.17";

        useDune2 = true;

        src = fetchFromGitHub {
          owner = "0install";
          repo = "0install";
          rev = "4a837bd638d93905b96d073c28c644894f8d4a0b";
          sha256 = "sha256-OsHJNh99oEQxCUH4GuV1sAlUhxCIxcW3oodgojgRskw=";
        };
      };

      opam-0install = ocamlPackages.buildDunePackage {
        pname = "opam-0install";
        version = "0.4.2";

        useDune2 = true;

        src = fetchFromGitHub {
          owner = "ocaml-opam";
          repo = "opam-0install-solver";
          rev = "eb08da5434a8c8227af39927b99b5cc15e82c053";
          sha256 = "sha256-+AD5zSAKZ4k2G+RsrKq1MxzjuGV4qdfOpt4TJxDMlEk=";
        };

        propagatedBuildInputs = with ocamlPackages; [
          opam-state
          zeroinstall-solver
          fmt
        ];
      };
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

        opam0install2nix = ocamlPackages.buildDunePackage {
          pname = "opam0install2nix";
          version = "0.0.0";

          useDune2 = true;

          src = self;

          buildInputs = with ocamlPackages; [
            opam-0install
            cmdliner
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
