{
  stdenv,
  lib,
  writeText,
  writeScript,
  runCommand,
  gnumake,
  jq,
  unzip,
  opamvars2nix,
  opamsubst2nix,
} @ args: let
  callPackage = lib.callPackageWith args;

  cleanVersion = lib.replaceStrings ["~"] ["-"];

  makeOpamLib = callPackage ./opam {inherit cleanVersion;};

  justExecutable = deriv:
    stdenv.mkDerivation {
      inherit (deriv) pname version;

      phases = ["installPhase"];

      installPhase = ''
        mkdir $out
        cp -r ${deriv}/bin $out
      '';
    };
in {
  inherit justExecutable makeOpamLib cleanVersion;
}
