{ lib, pkgs, ocamlPackages }:
{ envLib, filterLib, constraintLib, formulaLib }:

let
  evalCommands = commands:
    let
      keptCommands = builtins.filter ({ filter, ... }: filterLib.eval filter) commands;

      prunedCommands = builtins.map
        ({ args, ... }:
          let
            keptArgs = builtins.filter ({ filter, ... }: filterLib.eval filter) args;

            prunedArgs =
              builtins.map
                ({ arg, ... }: builtins.toJSON (envLib.eval { } arg))
                keptArgs;
          in
          prunedArgs
        )
        keptCommands;
    in
    prunedCommands;

  evalFilterFormula = formulaLib.evalBoolean { atom = filterLib.eval; };

  showConstraintFormula = subject: formulaLib.show { atom = constraintLib.show subject; };

  evalConstraintFormula = formulaLib.evalPredicate { atom = constraintLib.eval; };

  evalDependency = { optional ? false }: dep: dep {
    package = packageName: enabled: constraint:
      if builtins.hasAttr packageName ocamlPackages then
        let package = ocamlPackages.${packageName}; in
        (
          if evalFilterFormula enabled then
            (
              if evalConstraintFormula constraint package.version then
                [ package ]
              else
                null
            )
          else
            [ ]
        )
      else if optional then
        [ ]
      else
        null;
  };

  showDependency = dep: dep {
    package = packageName: enabled: constraint:
      if builtins.hasAttr packageName ocamlPackages then
        let package = ocamlPackages.${packageName}.name; in
        (
          if evalFilterFormula enabled then
            "${showConstraintFormula package constraint}"
          else
            "${packageName} disabled"
        )
      else
        "${packageName} is unknown";
  };

  evalDependenciesFormula = { name, ... }@config: depFormula:
    let downstreamConfig = builtins.removeAttrs config [ "name" ]; in
    let deps = formulaLib.evalList { atom = evalDependency downstreamConfig; } depFormula; in
    if builtins.isList deps then
      deps
    else
      let debugged =
        formulaLib.debug
          {
            evalAtom = dep: evalDependency downstreamConfig dep != null;
            showAtom = showDependency;
          }
          depFormula;
      in
      abort ''
        Dependency formula could not be satisfied for ${name}:
        ${debugged}
      '';

  evalNativeDependencies = nativeDepends:
    let
      findDep = packageName:
        if builtins.hasAttr packageName pkgs then
          pkgs.${packageName}
        else
          abort "Unknown native package ${packageName}";
    in
    builtins.concatMap
      ({ nativePackage, ... }: builtins.map findDep nativePackage)
      (builtins.filter ({ filter, ... }: filterLib.eval filter) nativeDepends);

  cleanVersion = builtins.replaceStrings [ "~" ] [ "-" ];

in
{
  inherit evalDependenciesFormula evalCommands evalNativeDependencies cleanVersion;
}
