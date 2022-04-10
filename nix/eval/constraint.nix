{ filterLib }:

let
  cleanVersion = builtins.replaceStrings [ "~" ] [ "-" ];

  compareVersions = lhs: rhs: builtins.compareVersions (cleanVersion lhs) (cleanVersion rhs);

  evalConstraint = constraint: version: constraint {
    equal = versionFilter:
      compareVersions version (filterLib.eval versionFilter) == 0;

    notEqual = versionFilter:
      compareVersions version (filterLib.eval versionFilter) != 0;

    greaterEqual = versionFilter:
      compareVersions version (filterLib.eval versionFilter) >= 0;

    greaterThan = versionFilter:
      compareVersions version (filterLib.eval versionFilter) > 0;

    lowerEqual = versionFilter:
      compareVersions version (filterLib.eval versionFilter) <= 0;

    lowerThan = versionFilter:
      compareVersions version (filterLib.eval versionFilter) < 0;
  };

  showConstraint = constraint: constraint {
    equal = versionFilter: "== ${filterLib.show versionFilter}";

    notEqual = versionFilter: "!= ${filterLib.show versionFilter}";

    greaterEqual = versionFilter: ">= ${filterLib.show versionFilter}";

    greaterThan = versionFilter: "> ${filterLib.show versionFilter}";

    lowerEqual = versionFilter: "<= ${filterLib.show versionFilter}";

    lowerThan = versionFilter: "< ${filterLib.show versionFilter}";
  };

in
{
  eval = evalConstraint;
  show = showConstraint;
}
