{
  buildDunePackage,
  opam-format,
  opam-state,
  ppxlib,
  ppx_deriving,
  cmdliner,
  zarith,
  hex,
  base64,
  nix,
  pkgs,
}:
buildDunePackage {
  pname = "opam2nix";
  version = "0.0.0";

  duneVersion = "3";
  minimumOCamlVersion = "4.13";

  src = ../../..;

  nativeBuildInputs = [pkgs.git];

  buildInputs = [
    opam-format
    opam-state
    ppxlib
    ppx_deriving
    cmdliner
    zarith
    hex
    base64
    nix
  ];
}
