let
  # Filter DSL.
  filterScope = { local, packages }: {
    bool = value: value;

    string = value: value;

    ident = pkgs: var: defaults:
      if pkgs == [ ] then
        if builtins.hasAttr var local then
          local.${var}
        else
          abort ("Unknown local variable: ${var}")
      else
        abort
          ("ident: ${builtins.toJSON [pkgs var defaults]}");

    equal = lhs: rhs: lhs == rhs;

    notEqual = lhs: rhs: lhs != rhs;

    greaterEqual = lhs: rhs: lhs >= rhs;

    greaterThan = lhs: rhs: lhs > rhs;

    lowerEqual = lhs: rhs: lhs <= rhs;

    lowerThan = lhs: rhs: lhs < rhs;

    def = _: abort "filterScope.def";

    undef = _: abort "filterScope.undef";
  };

  evalFilter = env: f: f (filterScope env);

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

  evalfilterOrConstraint = env: f: f (filterOrConstraintScope env);

  # Predicate DSL where values are functions from an unknown input to boolean.
  # Atoms are of type "filterOrConstraint".
  filterOrConstraintFormulaScope = env: {
    empty = _: true;

    atom = filterOrConstraint: evalfilterOrConstraint env filterOrConstraint;

    block = x: x;

    and = lhs: rhs: version: lhs version && rhs version;

    or = lhs: rhs: version: lhs version || rhs version;
  };

  evalFilterOrConstraintFormula = env: f: f (filterOrConstraintFormulaScope env);

  # Single indirection DSL - basically an expression of this will immediate call the "package"
  # attribute.
  dependencyScope = env: {
    package = package: formula:
      if evalFilterOrConstraintFormula env formula package.version then
        [ package ]
      else
        null;
  };

  evalDependency = env: f: f (dependencyScope env);

  # List concatenation/alternation DSL where a null value indicates failure, list value indicates
  # success.
  # Atoms are of type "dependency".
  dependenciesFormulaScope = env: {
    empty = null;

    atom = dependency: evalDependency env dependency;

    block = x: x;

    and = lhs: rhs: if lhs != null && rhs != null then lhs ++ rhs else null;

    or = lhs: rhs: if lhs != null then lhs else rhs;
  };

  evalDependenciesFormula = env: f:
    let
      deps = f (dependenciesFormulaScope env);
    in
    if builtins.isList deps then
      deps
    else
      abort "Some dependencies were not matched";

in

{
  inherit evalDependenciesFormula;
}
