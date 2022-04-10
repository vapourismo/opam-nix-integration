{ lib, newScope, ocaml, findlib }:

lib.makeScope newScope (self: {
  inherit ocaml;
  ocaml-base-compiler = self.ocaml;

  ocamlfind = findlib.override {
    inherit (self) ocaml;
  };
})
