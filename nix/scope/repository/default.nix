{
  lib,
  runCommand,
  callOpam2Nix,
  opam0install2nix,
  src,
}: let
  repositoryIndex = import ./repository-index.nix {inherit lib src;};

  packagePath = name: version:
    builtins.path {
      name = "opam-${name}-${version}";
      path = "${src}/packages/${name}/${name}.${version}";
    };

  callOpam = {
    name,
    version,
    src ? null,
    patches ? [],
  }:
    callOpam2Nix {
      inherit name version src patches;
      opam = "${packagePath name version}/opam";
      extraFiles = "${packagePath name version}/files";
    };

  fixPackageName = name: let
    fixedName = lib.replaceStrings ["+"] ["p"] name;
  in
    # Check if the name starts with a bad letter.
    if lib.strings.match "^[^a-zA-Z_].*" fixedName != null
    then "_${fixedName}"
    else fixedName;

  inferOpamLocation = import ../infer-opam-location.nix;

  solvePackageVersions = {
    packageConstraints ? [],
    testablePackages ? [],
    opams ? [],
  }: let
    testTargetArgs = lib.strings.escapeShellArgs (
      lib.lists.map (name: "--with-test-for=${name}") testablePackages
    );

    packageConstraintArgs = lib.strings.escapeShellArgs packageConstraints;

    pinArgs = lib.strings.escapeShellArgs (
      lib.lists.map
      (args: let
        fixed = inferOpamLocation args;
      in "--pin=${fixed.name}:${fixed.opam}")
      opams
    );

    versions = import (
      runCommand
      "opam0install2nix-solver"
      {
        buildInputs = [opam0install2nix];
      }
      ''
        opam0install2nix \
          --packages-dir="${src}/packages" \
          ${testTargetArgs} \
          ${packageConstraintArgs} \
          ${pinArgs} \
          > $out
      ''
    );
  in
    versions;
in {
  inherit callOpam;

  packages =
    lib.mapAttrs'
    (name: collection: {
      name = fixPackageName name;
      value =
        lib.listToAttrs
        (
          lib.lists.map
          (version: {
            name = version;
            value = callOpam {inherit name version;} {};
          })
          collection.versions
        )
        // {
          latest =
            callOpam
            {
              inherit name;
              version = collection.latest;
            }
            {};
        };
    })
    repositoryIndex;

  select = {testablePackages ? [], ...} @ args: let
    fixPackage = name: version: let
      pkg = callOpam {inherit name version;} {};
    in {
      name = fixPackageName name;
      value = pkg.override {with-test = lib.elem name testablePackages;};
    };

    pinnedPackages =
      lib.lists.map
      (opamArg: {
        name = opamArg.name;
        value = callOpam2Nix ({version = "pinned";} // opamArg) {};
      })
      (args.opams or []);
  in
    lib.mapAttrs' fixPackage (solvePackageVersions args) // lib.attrsets.listToAttrs pinnedPackages;
}
