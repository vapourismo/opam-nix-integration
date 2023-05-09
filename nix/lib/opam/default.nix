{
  stdenv,
  lib,
  writeText,
  writeScript,
  runCommand,
  gnumake,
  jq,
  unzip,
  opam2nix,
  cleanVersion,
} @ depends: let
  callPackage = lib.callPackageWith depends;

  formulaLib = callPackage ./formula {};
in
  args: let
    envLib = callPackage ./env {} args;

    filterLib = callPackage ./filter {inherit envLib;};

    constraintLib = callPackage ./constraint {inherit filterLib;};

    commandsLib = callPackage ./commands {inherit envLib filterLib;};

    dependsLib = callPackage ./depends {inherit envLib filterLib constraintLib formulaLib;};

    substLib = callPackage ./subst {inherit envLib;};

    sourceLib = callPackage ./source {inherit substLib;};
  in {
    formula = formulaLib;
    env = envLib;
    filter = filterLib;
    constraint = constraintLib;
    commands = commandsLib;
    depends = dependsLib;
    subst = substLib;
    source = sourceLib;
  }
