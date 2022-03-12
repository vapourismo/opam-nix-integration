let
  resolveVariable = { local, packages }: pkgs: var: defaults:
    if pkgs == [ ] || pkgs == [ "_" ] || pkgs == [ null ] then
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

  filterStringScope = env: {
    bool = builtins.toJSON;

    string = builtins.toJSON;

    ident = pkgs: var: defaults:
      let
        name =
          if pkgs == [ ] then
            var
          else
            builtins.concatStringsSep ":" (pkgs ++ [ var ]);

        value = builtins.toJSON (resolveVariable env pkgs var defaults);
      in
      "${value} (${name})";

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

  showFilter = env: f: f (filterStringScope env);

  filterFormulaScope = env: {
    empty = true;

    atom = evalFilter env;
  };

  evalFilterFormula = env: f:
    let
      cnf = f (filterFormulaScope env);

      evalOrs =
        builtins.foldl'
          (lhs: rhs: lhs || rhs)
          false;

      evalAnds =
        builtins.foldl'
          (lhs: rhs: lhs && rhs)
          true;

    in
    evalAnds (builtins.map evalOrs cnf);

  # Expressions of this DSL call exactly one of these functions.
  constraintScope = env: {
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

  evalConstraint = env: f: f (constraintScope env);

  constraintStringScope = env: {
    equal = versionFilter: packageName:
      "${packageName} == ${showFilter env versionFilter}";

    notEqual = versionFilter: packageName:
      "${packageName} != ${showFilter env versionFilter}";

    greaterEqual = versionFilter: packageName:
      "${packageName} >= ${showFilter env versionFilter}";

    greaterThan = versionFilter: packageName:
      "${packageName} > ${showFilter env versionFilter}";

    lowerEqual = versionFilter: packageName:
      "${packageName} <= ${showFilter env versionFilter}";

    lowerThan = versionFilter: packageName:
      "${packageName} < ${showFilter env versionFilter}";
  };

  showConstraint = env: f: f (constraintStringScope env);

  constraintFormulaScope = env: {
    empty = _: true;

    atom = evalConstraint env;
  };

  evalConstraintFormula = env: f:
    let
      cnf = f (constraintFormulaScope env);

      evalOrs =
        builtins.foldl'
          (lhs: rhs: version: lhs version || rhs version)
          (_: false);

      evalAnds =
        builtins.foldl'
          (lhs: rhs: version: lhs version && rhs version)
          (_: true);

    in
    evalAnds (builtins.map evalOrs cnf);

  constraintFormulaStringScope = env: {
    empty = packageName: "${packageName}";

    atom = showConstraint env;
  };

  showConstraintFormula = env: f:
    let
      cnf = f (constraintFormulaStringScope env);

      evalOrs = ors:
        if builtins.length ors > 0 then
          builtins.foldl'
            (lhs: rhs: packageName: "${lhs packageName} || ${rhs packageName}")
            (builtins.head ors)
            (builtins.tail ors)
        else
          _: "never";

      evalAnds = ands:
        if builtins.length ands > 0 then
          builtins.foldl'
            (lhs: rhs: packageName: "${lhs packageName} && ${rhs packageName}")
            (builtins.head ands)
            (builtins.tail ands)
        else
          _: "no constraint";

    in
    evalAnds (builtins.map (ors: p: "(${evalOrs ors p})") cnf);

  # Single indirection DSL - basically an expression of this will immediate call the "package"
  # attribute.
  dependencyScope = env: packages: {
    package = packageName: enabled: constraints:
      let package =
        if builtins.hasAttr packageName packages then
          packages.${packageName}
        else
          abort "Unknown package ${packageName}";
      in
      if evalFilterFormula env enabled then
        (
          if evalConstraintFormula env constraints package.version then
            [ package ]
          else
            null
        )
      else
        [ ];
  };

  evalDependency = env: packages: f: f (dependencyScope env packages);

  dependencyStringScope = env: packages: {
    package = packageName: enabled: constraints:
      let package =
        if builtins.hasAttr packageName packages then
          packages.${packageName}.name
        else
          packageName;
      in
      if evalFilterFormula env enabled then
        "${packageName}: ${showConstraintFormula env constraints package}"
      else
        "${packageName}: disabled";
  };

  showDependency = env: packages: f: f (dependencyStringScope env packages);

  dependenciesFormulaStringScope = env: packages: {
    empty = "empty";

    atom = showDependency env packages;
  };

  showDependenciesFormula = env: packages: f:
    let
      cnf = f (dependenciesFormulaStringScope env packages);

      evalOrs = ors:
        if builtins.length ors > 0 then
          builtins.foldl' (lhs: rhs: "${lhs} || ${rhs}") (builtins.head ors) (builtins.tail ors)
        else
          "false";

      evalAnds = ands:
        if builtins.length ands > 0 then
          builtins.foldl' (lhs: rhs: "${lhs}\n${rhs}") (builtins.head ands) (builtins.tail ands)
        else
          "true";
    in
    evalAnds (builtins.map evalOrs cnf);

  # List concatenation/alternation DSL where a null value indicates failure, list value indicates
  # success.
  # Atoms are of type "dependency".
  dependenciesFormulaScope = env: packages: {
    empty = [ ];

    atom = evalDependency env packages;
  };

  evalDependenciesFormula = env: packages: f:
    let
      cnf = f (dependenciesFormulaScope env packages);

      evalOrs =
        builtins.foldl'
          (lhs: rhs: if lhs != null then lhs else rhs)
          null;

      evalAnds =
        builtins.foldl'
          (lhs: rhs: if lhs != null && rhs != null then lhs ++ rhs else null)
          [ ];

      deps = evalAnds (builtins.map evalOrs cnf);

    in
    if builtins.isList deps then
      deps
    else
      abort ''
        Dependency formula could not be satisfied:
        ${showDependenciesFormula env packages f}
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
