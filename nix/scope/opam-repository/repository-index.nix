{ lib }:

opamRepository:

let
  packageDirs = builtins.readDir "${opamRepository}/packages";

  packageNames =
    builtins.filter
      (name: packageDirs.${name} == "directory")
      (builtins.attrNames packageDirs);

  getPackage = packageName:
    let
      versionDirs = builtins.readDir "${opamRepository}/packages/${packageName}";

      versionedNames =
        builtins.filter
          (versionedName:
            versionDirs.${versionedName} == "directory"
            && lib.strings.hasPrefix "${packageName}." versionedName
          )
          (builtins.attrNames versionDirs);

      versions =
        builtins.map
          (builtins.substring (builtins.stringLength packageName + 1) (-1))
          versionedNames;

      withLatest =
        if builtins.length versions > 0 then {
          latest =
            builtins.elemAt
              (builtins.sort
                (lhs: rhs: builtins.compareVersions lhs rhs >= 0)
                versions)
              0;
        } else { };
    in
    { inherit versions; } // withLatest;

in

builtins.listToAttrs (
  builtins.map
    (name: {
      inherit name;
      value = getPackage name;
    })
    packageNames
)
