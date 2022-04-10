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

  showConstraintFormula = formulaLib.show { atom = constraintLib.show; };

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
            "${packageName}: ${showConstraintFormula constraint}"
          else
            "${packageName}: disabled"
        )
      else
        "${packageName}: unknown package";
  };

  reduceDependencyFormula = config: dep:
    let
      cnf = dep {
        empty = {
          eval = true;
          string = "empty";
        };

        atom = dep: {
          eval = evalDependency config dep != null;
          string = showDependency dep;
        };
      };

      evalOrs =
        builtins.foldl'
          (lhs: rhs:
            if lhs.eval || rhs.eval then
              { eval = true; string = "true"; }
            else
              {
                eval = false;
                string = "${lhs.string} or \n${rhs.string}";
              }
          )
          {
            eval = false;
            string = "false";
          };

      evalAnds =
        builtins.foldl'
          (lhs: rhs:
            if lhs.eval && rhs.eval then
              {
                eval = true;
                string = "true";
              }
            else if lhs.eval then
              rhs
            else if rhs.eval then
              lhs
            else
              {
                eval = false;
                string = "${lhs.string}, \n${rhs.string}";
              }
          )
          {
            eval = true;
            string = "true";
          };

      deps = evalAnds (builtins.map evalOrs cnf);

    in
    deps.string;

  evalDependenciesFormula = { name, ... }@config: f:
    let downstreamConfig = builtins.removeAttrs config [ "name" ]; in
    let deps = formulaLib.evalList { atom = evalDependency downstreamConfig; } f; in
    if builtins.isList deps then
      deps
    else
      abort ''
        Dependency formula could not be satisfied for ${name}:
        ${reduceDependencyFormula downstreamConfig f}
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
