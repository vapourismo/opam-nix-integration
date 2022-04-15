{ lib, pkgs }:
{ envLib, filterLib, constraintLib, formulaLib, ocamlPackages }:

let
  evalFilterFormula = formulaLib.evalBoolean { atom = filterLib.eval; };

  showConstraintFormula = subject: formulaLib.show { atom = constraintLib.show subject; };

  evalConstraintFormula = formulaLib.evalPredicate { atom = constraintLib.eval; };

  evalDependency = { optional ? false }: dep: dep {
    package = packageName: enabled: constraint:
      let want = evalFilterFormula enabled; in
      if builtins.hasAttr packageName ocamlPackages && want then
        let package = ocamlPackages.${packageName}; in
        (
          if evalConstraintFormula constraint package.version then
            [ package ]
          else
            null
        )
      else if optional || !want then
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

  interpolate = envLib.eval { onMissing = _: _: null; };

in

{
  inherit evalDependenciesFormula evalNativeDependencies interpolate;
}
