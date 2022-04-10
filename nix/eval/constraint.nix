{ filterLib }:

let
  cleanVersion = builtins.replaceStrings [ "~" ] [ "-" ];

  compareVersions = lhs: rhs: builtins.compareVersions (cleanVersion lhs) (cleanVersion rhs);

  constraintScopeEval = {
    always = filter: _: filterLib.eval filter;

    equal = versionFilter: packageVersion:
      compareVersions packageVersion (filterLib.eval versionFilter) == 0;

    notEqual = versionFilter: packageVersion:
      compareVersions packageVersion (filterLib.eval versionFilter) != 0;

    greaterEqual = versionFilter: packageVersion:
      compareVersions packageVersion (filterLib.eval versionFilter) >= 0;

    greaterThan = versionFilter: packageVersion:
      compareVersions packageVersion (filterLib.eval versionFilter) > 0;

    lowerEqual = versionFilter: packageVersion:
      compareVersions packageVersion (filterLib.eval versionFilter) <= 0;

    lowerThan = versionFilter: packageVersion:
      compareVersions packageVersion (filterLib.eval versionFilter) < 0;
  };

  evalConstraint = constraint: constraint constraintScopeEval;

  constraintScopeShow = {
    equal = versionFilter: packageName:
      "${packageName} == ${filterLib.show versionFilter}";

    notEqual = versionFilter: packageName:
      "${packageName} != ${filterLib.show versionFilter}";

    greaterEqual = versionFilter: packageName:
      "${packageName} >= ${filterLib.show versionFilter}";

    greaterThan = versionFilter: packageName:
      "${packageName} > ${filterLib.show versionFilter}";

    lowerEqual = versionFilter: packageName:
      "${packageName} <= ${filterLib.show versionFilter}";

    lowerThan = versionFilter: packageName:
      "${packageName} < ${filterLib.show versionFilter}";
  };

  showConstraint = constraint: constraint constraintScopeShow;

in
{
  eval = evalConstraint;
  show = showConstraint;
}
