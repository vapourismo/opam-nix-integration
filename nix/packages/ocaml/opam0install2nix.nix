{ buildDunePackage
, opam-0install
, cmdliner
, zarith
, hex
, base64
, pkgs
}:

buildDunePackage {
  pname = "opam0install2nix";
  version = "0.0.0";

  useDune2 = true;
  minimumOCamlVersion = "4.13";

  src = ../../..;

  buildInputs = [
    opam-0install
    cmdliner
    zarith
    hex
    base64
    pkgs.git
  ];
}
