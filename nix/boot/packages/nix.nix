{ buildDunePackage
, zarith
, pkgs
}:

buildDunePackage {
  pname = "nix";
  version = "0.0.0";

  duneVersion = "3";
  minimumOCamlVersion = "4.13";

  src = ../../..;

  buildInputs = [
    zarith
    pkgs.git
  ];
}
