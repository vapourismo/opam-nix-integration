{ lib
, runCommand
, gnumake
, opamvars2nix
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
in

{
  formula = formulaLib;
  env = envLib;
  filter = filterLib;
  constraint = constraintLib;
  commands = commandsLib;
}
