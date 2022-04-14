{ lib, writeText, newScope, ocaml, findlib }:

lib.makeScope newScope (self: {
  inherit ocaml;
  ocaml-base-compiler = self.ocaml;

  ocamlfind = import ../findlib.nix {
    inherit writeText;

    findlib = findlib.override {
      inherit (self) ocaml;
    };
  };
})
