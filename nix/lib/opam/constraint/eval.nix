{ filterLib, cleanVersion }:

let
  compareVersions = lhs: rhs: builtins.compareVersions (cleanVersion lhs) (cleanVersion rhs);
in

constraint: version: constraint {
  equal = versionFilter: compareVersions version (filterLib.eval versionFilter) == 0;

  notEqual = versionFilter: compareVersions version (filterLib.eval versionFilter) != 0;

  greaterEqual = versionFilter: compareVersions version (filterLib.eval versionFilter) >= 0;

  greaterThan = versionFilter: compareVersions version (filterLib.eval versionFilter) > 0;

  lowerEqual = versionFilter: compareVersions version (filterLib.eval versionFilter) <= 0;

  lowerThan = versionFilter: compareVersions version (filterLib.eval versionFilter) < 0;
}
