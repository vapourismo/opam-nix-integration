{ buildDunePackage
, opam-format
, zarith
}:

buildDunePackage {
  pname = "opamsubst2nix";
  version = "0.0.0";

  useDune2 = true;

  src = ../../..;

  buildInputs = [
    opam-format
    zarith
  ];
}
