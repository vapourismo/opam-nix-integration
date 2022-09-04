{ lib, pkgs, envLib, filterLib, constraintLib, formulaLib }:

let
  evalCondition = formulaLib.evalBoolean { atom = filterLib.eval; };

  showConstraint = subject: formulaLib.show { atom = constraintLib.show subject; };

  evalConstraint = formulaLib.evalPredicate { atom = constraintLib.eval; };

  evalDependency = { optional ? false }: dep: dep {
    package = { name, package, enabled, constraint }:
      let want = evalCondition enabled; in
      if want && package != null then
        (
          if evalConstraint constraint package.version then
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
    package = { name, package, enabled, constraint }:
      let want = evalCondition enabled; in
      if want && package != null then
        "${showConstraint package constraint}"
      else if !want then
        "${name} disabled"
      else
        "${name} is unknown";
  };

  eval = { name, ... }@config: depFormula:
    let
      downstreamConfig = builtins.removeAttrs config [ "name" ];
      deps = formulaLib.evalList { atom = evalDependency downstreamConfig; } depFormula;
    in
    if lib.isList deps then
      deps
    else
      let
        debugged =
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

  guessNativeDepends = nativeDepends:
    let
      pkgToAttrEntry = pkg: {
        name = pkg;
        value =
          if lib.hasAttr pkg pkgs && (builtins.tryEval pkgs.${pkg}).success then
            pkgs.${pkg}
          else
            null;
      };

      pkgsSet = lib.listToAttrs (
        lib.concatMap
          ({ nativePackages, ... }:
            lib.lists.map
              pkgToAttrEntry
              nativePackages
          )
          nativeDepends
      );
    in
    lib.attrValues (lib.filterAttrs (_: value: value != null) pkgsSet);

  evalNative = nativeDepends:
    let
      findDep = packageName:
        if lib.hasAttr packageName pkgs then
          pkgs.${packageName}
        else
          abort "Unknown native package ${packageName}";

      nativeDeps =
        lib.concatMap
          ({ nativePackages, ... }: lib.lists.map findDep nativePackages)
          (lib.filter ({ filter, ... }: filterLib.eval filter) nativeDepends);
    in
    if lib.length nativeDeps > 0 then
      nativeDeps
    else
      guessNativeDepends nativeDepends;

in

{
  inherit eval evalNative;
}
