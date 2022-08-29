{ buildDunePackage
, opam-format
, zarith
, base64
, hex
, nix
, pkgs
}:

buildDunePackage {
  pname = "opamsubst2nix";
  version = "0.0.0";

  duneVersion = "3";
  minimumOCamlVersion = "4.13";

  src = ../../..;

  buildInputs = [
    opam-format
    zarith
    base64
    hex
    nix
    pkgs.git
  ];
}
