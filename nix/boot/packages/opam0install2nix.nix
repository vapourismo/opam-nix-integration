{ buildDunePackage
, opam-0install
, cmdliner
, zarith
, hex
, base64
, nix
, pkgs
}:

buildDunePackage {
  pname = "opam0install2nix";
  version = "0.0.0";

  duneVersion = "3";
  minimumOCamlVersion = "4.13";

  src = ../../..;

  buildInputs = [
    opam-0install
    cmdliner
    zarith
    hex
    base64
    nix
    pkgs.git
  ];
}
