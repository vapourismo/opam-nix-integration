{ lib, filterLib, cleanVersion }:

let
  compareVersions = lhs: rhs:
    # We treat 'base' in a special way. It indicates that a package came with
    # the compiler.
    if lhs == "base" && rhs == "base" then
      0
    else if lhs == "base" then
      1
    else if rhs == "base" then
      -1
    else
      lib.strings.compareVersions (cleanVersion lhs) (cleanVersion rhs);
in

constraint: version: constraint {
  equal = versionFilter: compareVersions version (filterLib.eval versionFilter) == 0;

  notEqual = versionFilter: compareVersions version (filterLib.eval versionFilter) != 0;

  greaterEqual = versionFilter: compareVersions version (filterLib.eval versionFilter) >= 0;

  greaterThan = versionFilter: compareVersions version (filterLib.eval versionFilter) > 0;

  lowerEqual = versionFilter: compareVersions version (filterLib.eval versionFilter) <= 0;

  lowerThan = versionFilter: compareVersions version (filterLib.eval versionFilter) < 0;
}
