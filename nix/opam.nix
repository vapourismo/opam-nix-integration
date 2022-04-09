{ lib, callPackage }:

let
  evalCommands = env: commands:
    let
      keptCommands = builtins.filter ({ filter, ... }: evalFilter env filter) commands;

      prunedCommands = builtins.map
        ({ args, ... }:
          let
            keptArgs = builtins.filter ({ filter, ... }: evalFilter env filter) args;

            prunedArgs =
              builtins.map
                ({ arg, ... }: builtins.toJSON (env.eval arg))
                keptArgs;
          in
          prunedArgs
        )
        keptCommands;
    in
    prunedCommands;

  # Filter DSL.
  filterScope = env: {
    bool = value: value;

    string = value: value;

    ident = env.eval;

    equal = lhs: rhs: lhs == rhs;

    notEqual = lhs: rhs: lhs != rhs;

    greaterEqual = lhs: rhs: lhs >= rhs;

    greaterThan = lhs: rhs: lhs > rhs;

    lowerEqual = lhs: rhs: lhs <= rhs;

    lowerThan = lhs: rhs: lhs < rhs;

    and = lhs: rhs: lhs && rhs;

    or = lhs: rhs: lhs || rhs;

    not = x: !x;

    def = _: abort "filterScope.def";

    undef = _: abort "filterScope.undef";
  };

  evalFilter = env: f: f (filterScope env);

  filterStringScope = env: {
    bool = builtins.toJSON;

    string = builtins.toJSON;

    ident = f:
      let value = env.eval f; in
      {

        local = { name, ... }: "${value} (${name})";

        package = { packageName, name, ... }: "${value} (${packageName}:${name})";

        combine = values:
          lib.foldl'
            (lhs: rhs: "${lhs} & ${rhs}")
            (lib.head values)
            (lib.tail values);
      };

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

  compareVersions = lhs: rhs: builtins.compareVersions (cleanVersion lhs) (cleanVersion rhs);

  # Expressions of this DSL call exactly one of these functions.
  constraintScope = env: {
    always = filter: _: evalFilter env filter;

    equal = versionFilter: packageVersion:
      compareVersions packageVersion (evalFilter env versionFilter) == 0;

    notEqual = versionFilter: packageVersion:
      compareVersions packageVersion (evalFilter env versionFilter) != 0;

    greaterEqual = versionFilter: packageVersion:
      compareVersions packageVersion (evalFilter env versionFilter) >= 0;

    greaterThan = versionFilter: packageVersion:
      compareVersions packageVersion (evalFilter env versionFilter) > 0;

    lowerEqual = versionFilter: packageVersion:
      compareVersions packageVersion (evalFilter env versionFilter) <= 0;

    lowerThan = versionFilter: packageVersion:
      compareVersions packageVersion (evalFilter env versionFilter) < 0;
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

  dependencyScope = env: packages: {
    package = packageName: enabled: constraints:
      if builtins.hasAttr packageName packages then
        (
          let
            package = packages.${packageName};
          in
          if evalFilterFormula env enabled then
            (
              if evalConstraintFormula env constraints packages.${packageName}.version then
                [ package ]
              else
                null
            )
          else
            [ ]
        )
      else
        null;

    optionalPackage = packageName: enabled: constraints:
      if builtins.hasAttr packageName packages then
        let package =
          packages.${packageName};
        in
        (
          if evalFilterFormula env enabled then
            (
              if evalConstraintFormula env constraints package.version then
                [ package ]
              else
                null
            )
          else
            [ ]
        )
      else
        [ ];
  };

  evalDependency = env: packages: f: f (dependencyScope env packages);

  dependencyStringScope = env: packages: {
    package = packageName: enabled: constraints:
      if builtins.hasAttr packageName packages then
        (
          let package =
            packages.${packageName}.name;
          in
          if evalFilterFormula env enabled then
            "${packageName}: ${showConstraintFormula env constraints package}"
          else
            "${packageName}: disabled"
        )
      else
        "${packageName}: unknown package";

    optionalPackage = packageName: enabled: constraints:
      if builtins.hasAttr packageName packages then
        let package =
          packages.${packageName}.name;
        in
        (
          if evalFilterFormula env enabled then
            "${packageName}: ${showConstraintFormula env constraints package}"
          else
            "${packageName}: disabled"
        )
      else
        "${packageName}: unknown package";
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

  dependenciesFormulaReduceScope = env: packages: {
    empty = [ ];

    atom = atom: {
      eval = evalDependency env packages atom != null;
      string = showDependency env packages atom;
    };
  };

  reduceDependencyFormula = env: packages: f:
    let
      cnf = f (dependenciesFormulaReduceScope env packages);

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

  dependenciesFormulaScope = env: packages: {
    empty = [ ];

    atom = evalDependency env packages;
  };

  evalDependenciesFormula = name: env: packages: f:
    let
      cnf = f (dependenciesFormulaScope env packages);

      evalOrs =
        builtins.foldl'
          (lhs: rhs:
            if lhs != null && rhs != null then
              lhs ++ rhs
            else if lhs != null then
              lhs
            else
              rhs
          )
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
        Dependency formula could not be satisfied for ${name}:
        ${reduceDependencyFormula env packages f}
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

  cleanVersion = builtins.replaceStrings [ "~" ] [ "-" ];

in

{
  inherit evalDependenciesFormula evalCommands evalNativeDependencies cleanVersion;
}
