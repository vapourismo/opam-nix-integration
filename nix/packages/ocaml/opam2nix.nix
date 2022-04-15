{ buildDunePackage
, opam-format
, opam-state
, ppxlib
, ppx_deriving
, cmdliner
, zarith
}:

buildDunePackage {
  pname = "opam2nix";
  version = "0.0.0";

  useDune2 = true;

  src = ../../..;

  buildInputs = [
    opam-format
    opam-state
    ppxlib
    ppx_deriving
    cmdliner
    zarith
  ];
}
