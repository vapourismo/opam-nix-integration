{
  pkgs,
  stdenv,
  lib,
  system,
  runCommand,
  writeText,
  writeScript,
  opam-installer,
  opam2nix,
  opamvars2nix,
  opamsubst2nix,
  opam0install2nix,
  repository,
} @ args: let
  callPackage = lib.callPackageWith args;

  opamScope = callPackage ../opam {};

  repositoryIndex = callPackage ./repository-index.nix {} repository;

  packagePath = name: version: "${repository}/packages/${name}/${name}.${version}";

  solvePackageVersions = {
    packageConstraints ? [],
    testablePackages ? [],
  }: let
    testTargetArgs = lib.strings.escapeShellArgs (
      lib.lists.map (name: "--with-test-for=${name}") testablePackages
    );

    packageConstraintArgs = lib.strings.escapeShellArgs packageConstraints;

    versions = import (
      runCommand
      "opam0install2nix-solver"
      {
        buildInputs = [opam0install2nix];
      }
      ''
        opam0install2nix \
          --packages-dir="${repository}/packages" \
          ${testTargetArgs} \
          ${packageConstraintArgs} \
          > $out
      ''
    );
  in
    versions;

  fixPackageName = name: let
    fixedName = pkgs.lib.replaceStrings ["+"] ["p"] name;
  in
    # Check if the name starts with a bad letter.
    if lib.strings.match "^[^a-zA-Z_].*" fixedName != null
    then "_${fixedName}"
    else fixedName;
in
  opamScope.overrideScope' (final: prev: {
    callOpam = {
      name,
      version,
      src ? null,
      patches ? [],
    }:
      final.callOpam2Nix {
        inherit name version src patches;
        opam = "${packagePath name version}/opam";
        extraFiles = "${packagePath name version}/files";
      };

    repository = {
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
                value = final.callOpam {inherit name version;} {};
              })
              collection.versions
            )
            // {
              latest =
                final.callOpam
                {
                  inherit name;
                  version = collection.latest;
                }
                {};
            };
        })
        repositoryIndex;

      select = {testablePackages ? [], ...} @ args:
        lib.mapAttrs'
        (name: version: {
          name = fixPackageName name;
          value = let
            pkg = final.callOpam {inherit name version;} {};
          in
            pkg.override {with-test = lib.elem name testablePackages;};
        })
        (solvePackageVersions args);
    };
  })
