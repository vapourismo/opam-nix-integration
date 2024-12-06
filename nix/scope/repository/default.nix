{
  lib,
  runCommand,
  callOpam2Nix,
  opam2nix,
  src,
  srcs ? [src],
}: let
  mergedRepoSrc =
    if lib.length srcs == 0
    then
      runCommand "empty-opam-repository" {} ''
        mkdir -p $out/packages
      ''
    else if lib.length srcs == 1
    then lib.elemAt srcs 0
    else
      runCommand "merged-opam-repository" {inherit srcs;} ''
        set -x
        mkdir -p $out/packages
        for src in $srcs; do
          packages_dir="$src/packages"
          for name in $(ls -1 "$packages_dir"); do
            package_dir="$packages_dir/$name"
            mkdir -p "$out/packages/$name"
            ln -sfv -t "$out/packages/$name" $(find "$package_dir" -mindepth 1 -maxdepth 1)
          done
        done
      '';

  repositoryIndex = import ./repository-index.nix {
    inherit lib;
    src = mergedRepoSrc;
  };

  cleanVersion = lib.replaceStrings ["~"] ["-"];

  packagePath = name: version:
    builtins.path {
      name = "opam-${name}-${cleanVersion version}";
      path = "${mergedRepoSrc}/packages/${name}/${name}.${version}";
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
      "solve-for-opam2nix"
      {
        buildInputs = [opam2nix];
      }
      ''
        opam2nix solve-0install \
          --packages-dir="${mergedRepoSrc}/packages" \
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
