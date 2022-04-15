{ buildDunePackage
, opam-format
, opam-state
, zarith
, pkgs
}:

buildDunePackage {
  pname = "opamvars2nix";
  version = "0.0.0";

  useDune2 = true;
  minimumOCamlVersion = "4.13";

  src = ../../..;

  buildInputs = [
    opam-format
    opam-state
    zarith
    pkgs.git
  ];
}
