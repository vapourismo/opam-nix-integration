{ buildDunePackage
, opam-format
, zarith
, base64
, hex
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
    base64
    hex
    pkgs.git
  ];
}
