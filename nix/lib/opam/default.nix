{ lib
, pkgs
, writeText
, runCommand
, gnumake
, opamvars2nix
, opamsubst2nix
, cleanVersion
}:

let
  formulaLib = import ./formula { inherit lib; };
in

args:

let
  envLib = import ./env { inherit lib runCommand gnumake opamvars2nix; } args;

  filterLib = import ./filter { inherit lib envLib; };

  constraintLib = import ./constraint { inherit filterLib cleanVersion; };

  commandsLib = import ./commands { inherit lib envLib filterLib; };

  dependsLib =
    import ./depends
      { inherit lib pkgs envLib filterLib constraintLib formulaLib; }
      { inherit (args) ocamlPackages; };

  substLib = import ./subst { inherit writeText runCommand opamsubst2nix envLib; };
in

{
  formula = formulaLib;
  env = envLib;
  filter = filterLib;
  constraint = constraintLib;
  commands = commandsLib;
  depends = dependsLib;
  subst = substLib;
}