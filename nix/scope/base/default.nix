{ lib, system, writeText, newScope, findlib }:

lib.makeScope newScope (self: {
  ocamlfind = import ./fix-findlib.nix {
    inherit system writeText;

    findlib = findlib.override {
      ocaml = self.ocaml-base-compiler;
    };
  };
})
