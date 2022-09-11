{ lib, src }:

let
  packageDirs = builtins.readDir "${src}/packages";

  packageNames =
    lib.filter
      (name: packageDirs.${name} == "directory")
      (lib.attrNames packageDirs);

  getPackage = packageName:
    let
      versionDirs = builtins.readDir "${src}/packages/${packageName}";

      versionedNames =
        lib.filter
          (versionedName:
            versionDirs.${versionedName} == "directory"
            && lib.strings.hasPrefix "${packageName}." versionedName
          )
          (lib.attrNames versionDirs);

      versions =
        lib.lists.map
          (lib.substring (lib.stringLength packageName + 1) (-1))
          versionedNames;

      withLatest =
        if lib.length versions > 0 then {
          latest =
            lib.elemAt
              (lib.sort
                (lhs: rhs: lib.strings.compareVersions lhs rhs >= 0)
                versions)
              0;
        } else { };
    in
    { inherit versions; } // withLatest;
in

lib.listToAttrs (
  lib.lists.map
    (name: {
      inherit name;
      value = getPackage name;
    })
    packageNames
)
