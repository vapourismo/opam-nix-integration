{ buildDunePackage
, opam-format
, zarith
, pkgs
}:

buildDunePackage {
  pname = "opamsubst2nix";
  version = "0.0.0";

  useDune2 = true;
  minimumOCamlVersion = "4.13";

  src = ../../..;

  buildInputs = [
    opam-format
    zarith
    pkgs.git
  ];
}
