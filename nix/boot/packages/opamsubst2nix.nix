{
  buildDunePackage,
  opam-format,
  zarith,
  base64,
  hex,
  nix,
  pkgs,
}:
buildDunePackage {
  pname = "opamsubst2nix";
  version = "0.0.0";

  duneVersion = "3";
  minimumOCamlVersion = "4.13";

  src = ../../..;

  nativeBuildInputs = [pkgs.git];

  buildInputs = [
    opam-format
    zarith
    base64
    hex
    nix
  ];
}
