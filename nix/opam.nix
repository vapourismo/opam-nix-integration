let
  resolveVariable = { local, packages }: pkgs: var: defaults:
    if pkgs == [ ] || pkgs == [ "_" ] then
      if builtins.hasAttr var local then
        local.${var}
      else
        abort ("Unknown local variable: ${var}")
    else
      abort
        ("ident: ${builtins.toJSON [pkgs var defaults]}");

  argScope = env: {
    ident = resolveVariable env;
  };

  evalArg = env: f: f (argScope env);

  evalCommands = env: commands:
    let
      keptCommands = builtins.filter ({ filter, ... }: evalFilter env filter) commands;

      prunedCommands = builtins.map
        ({ args, ... }:
          let
            keptArgs = builtins.filter ({ filter, ... }: evalFilter env filter) args;

            prunedArgs = builtins.map ({ arg, ... }: builtins.toJSON (evalArg env arg)) keptArgs;
          in
          builtins.concatStringsSep " " prunedArgs
        )
        keptCommands;
    in
    builtins.concatStringsSep "\n" prunedCommands;

  # Filter DSL.
  filterScope = env: {
    bool = value: value;

    string = value: value;

    ident = resolveVariable env;

    equal = lhs: rhs: lhs == rhs;

    notEqual = lhs: rhs: lhs != rhs;

    greaterEqual = lhs: rhs: lhs >= rhs;

    greaterThan = lhs: rhs: lhs > rhs;

    lowerEqual = lhs: rhs: lhs <= rhs;

    lowerThan = lhs: rhs: lhs < rhs;

    and = lhs: rhs: lhs && rhs;

    or = lhs: rhs: lhs || rhs;

    def = _: abort "filterScope.def";

    undef = _: abort "filterScope.undef";
  };

  evalFilter = env: f: f (filterScope env);

  filterStringScope = {
    bool = builtins.toJSON;

    string = builtins.toJSON;

    ident = pkgs: var: _defaults:
      let
        prefix = if pkgs == [ ] then "_" else builtins.concatStringsSep ":" pkgs;
      in
      "${prefix}:${var}";

    equal = lhs: rhs: "${lhs} == ${rhs}";

    notEqual = lhs: rhs: "${lhs} != ${rhs}";

    greaterEqual = lhs: rhs: "${lhs} >= ${rhs}";

    greaterThan = lhs: rhs: "${lhs} > ${rhs}";

    lowerEqual = lhs: rhs: "${lhs} <= ${rhs}";

    lowerThan = lhs: rhs: "${lhs} < ${rhs}";

    and = lhs: rhs: "${lhs} && ${rhs}";

    or = lhs: rhs: "${lhs} || ${rhs}";

    def = _: abort "filterScope.def";

    undef = _: abort "filterScope.undef";
  };

  showFilter = f: f filterStringScope;

  # Expressions of this DSL call exactly one of these functions.
  filterOrConstraintScope = env: {
    always = filter: _: evalFilter env filter;

    equal = versionFilter: packageVersion:
      builtins.compareVersions packageVersion (evalFilter env versionFilter) == 0;

    notEqual = versionFilter: packageVersion:
      builtins.compareVersions packageVersion (evalFilter env versionFilter) != 0;

    greaterEqual = versionFilter: packageVersion:
      builtins.compareVersions packageVersion (evalFilter env versionFilter) >= 0;

    greaterThan = versionFilter: packageVersion:
      builtins.compareVersions packageVersion (evalFilter env versionFilter) > 0;

    lowerEqual = versionFilter: packageVersion:
      builtins.compareVersions packageVersion (evalFilter env versionFilter) <= 0;

    lowerThan = versionFilter: packageVersion:
      builtins.compareVersions packageVersion (evalFilter env versionFilter) < 0;
  };

  evalFilterOrConstraint = env: f: f (filterOrConstraintScope env);

  filterOrConstraintStringScope = {
    always = filter: _: showFilter filter;

    equal = versionFilter: packageName:
      "${packageName} == ${showFilter versionFilter}";

    notEqual = versionFilter: packageName:
      "${packageName} != ${showFilter versionFilter}";

    greaterEqual = versionFilter: packageName:
      "${packageName} >= ${showFilter versionFilter}";

    greaterThan = versionFilter: packageName:
      "${packageName} > ${showFilter versionFilter}";

    lowerEqual = versionFilter: packageName:
      "${packageName} <= ${showFilter versionFilter}";

    lowerThan = versionFilter: packageName:
      "${packageName} < ${showFilter versionFilter}";
  };

  showFilterOrConstraint = f: f filterOrConstraintStringScope;

  # Predicate DSL where values are functions from an unknown input to boolean.
  # Atoms are of type "filterOrConstraint".
  filterOrConstraintFormulaScope = env: {
    empty = _: true;

    atom = filterOrConstraint: evalFilterOrConstraint env filterOrConstraint;

    block = x: x;

    and = lhs: rhs: version: lhs version && rhs version;

    or = lhs: rhs: version: lhs version || rhs version;
  };

  evalFilterOrConstraintFormula = env: f: f (filterOrConstraintFormulaScope env);

  filterOrConstraintFormulaStringScope = {
    empty = packageName: "${packageName}";

    atom = showFilterOrConstraint;

    block = x: x;

    and = lhs: rhs: packageName: "${lhs packageName} && ${rhs packageName}";

    or = lhs: rhs: packageName: "${lhs packageName} || ${rhs packageName}";
  };

  showFilterOrConstraintFormula = f: f filterOrConstraintFormulaStringScope;

  # Single indirection DSL - basically an expression of this will immediate call the "package"
  # attribute.
  dependencyScope = env: packages: {
    package = packageName: formula:
      let package =
        if builtins.hasAttr packageName packages then
          packages.${packageName}
        else
          abort "Unknown package ${packageName}";
      in
      if evalFilterOrConstraintFormula env formula package.version then
        [ package ]
      else
        null;
  };

  evalDependency = env: packages: f: f (dependencyScope env packages);

  dependencyStringScope = {
    package = packageName: formula:
      showFilterOrConstraintFormula formula packageName;
  };

  showDependency = f: f dependencyStringScope;

  dependenciesFormulaStringScope = {
    empty = "empty";

    atom = showDependency;

    block = x: x;

    and = lhs: rhs: "${lhs} && ${rhs}";

    or = lhs: rhs: "${lhs} || ${rhs}";
  };

  showDependenciesFormula = f: f dependenciesFormulaStringScope;

  # List concatenation/alternation DSL where a null value indicates failure, list value indicates
  # success.
  # Atoms are of type "dependency".
  dependenciesFormulaScope = env: packages: {
    empty = [ ];

    atom = evalDependency env packages;

    block = x: x;

    and = lhs: rhs: if lhs != null && rhs != null then lhs ++ rhs else null;

    or = lhs: rhs: if lhs != null then lhs else rhs;
  };

  evalDependenciesFormula = env: packages: f:
    let
      deps = f (dependenciesFormulaScope env packages);
    in
    if builtins.isList deps then
      deps
    else
      abort ''
        Dependency formula could not be satisfied:
        ${showDependenciesFormula f}
      '';

  evalNativeDependencies = env: nativePackages: nativeDepends:
    let
      findDep = packageName:
        if builtins.hasAttr packageName nativePackages then
          nativePackages.${packageName}
        else
          abort "Unknown native package ${packageName}";
    in
    builtins.concatMap
      ({ packages, ... }: builtins.map findDep packages)
      (builtins.filter ({ filter, ... }: evalFilter env filter) nativeDepends);

in

{
  inherit evalDependenciesFormula evalCommands evalNativeDependencies;
}
