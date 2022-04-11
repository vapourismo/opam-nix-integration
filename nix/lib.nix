{ stdenv
, lib
, runCommand
, gnumake
, opamvars2nix
}@args:

let
  callPackage = lib.callPackageWith args;

  makeEvalLib = args: rec {
    env = callPackage ./eval/env.nix { } args;

    filter = callPackage ./eval/filter.nix { } { envLib = env; };

    constraint = import ./eval/constraint.nix { filterLib = filter; };

    formula = callPackage ./eval/formula.nix { };
  };

  justExecutable = deriv: stdenv.mkDerivation {
    inherit (deriv) pname version;

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir $out
      cp -r ${deriv}/bin $out
    '';
  };

  cleanVersion = builtins.replaceStrings [ "~" ] [ "-" ];

in
{
  inherit justExecutable makeEvalLib cleanVersion;
}
