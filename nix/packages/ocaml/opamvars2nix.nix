{ buildDunePackage
, opam-format
, opam-state
, zarith
}:

buildDunePackage {
  pname = "opamvars2nix";
  version = "0.0.0";

  useDune2 = true;

  src = ../../..;

  buildInputs = [
    opam-format
    opam-state
    zarith
  ];
}
