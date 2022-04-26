{ pkgs
, stdenv
, lib
, system
, newScope
, runCommand
, writeText
, writeScript
, opam-installer
, opam2nix
, opamvars2nix
, opamsubst2nix
, opam0install2nix
, repository
}@args:

let
  callPackage = lib.callPackageWith args;

  opamScope = callPackage ../opam { };

  repositoryIndex = callPackage ./repository-index.nix { } repository;

  packagePath = name: version: "${repository}/packages/${name}/${name}.${version}";

  solvePackageVersions =
    { packageConstraints ? [ ]
    , testablePackages ? [ ]
    }:
    let
      testTargetArgs = lib.strings.escapeShellArgs (
        lib.lists.map (name: "--with-test-for=${name}") testablePackages
      );

      packageConstraintArgs = lib.strings.escapeShellArgs packageConstraints;

      versions = import (
        runCommand
          "opam0install2nix-solver"
          {
            buildInputs = [ opam0install2nix ];
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
in

opamScope.overrideScope' (final: prev: {
  callOpam = { name, version, src ? null, patches ? [ ] }: args:
    final.callOpam2Nix
      {
        inherit name version src patches;
        opam = "${packagePath name version}/opam";
      }
      ({ extraSrc = "${packagePath name version}/files"; } // args);

  repository = {
    packages =
      lib.mapAttrs
        (name: collection:
          lib.listToAttrs
            (
              lib.lists.map
                (version: {
                  name = version;
                  value = final.callOpam { inherit name version; } { };
                })
                collection.versions
            ) // {
            latest =
              final.callOpam
                { inherit name; version = collection.latest; }
                { };
          })
        repositoryIndex;

    select = { testablePackages ? [ ], ... }@args:
      lib.mapAttrs
        (name: version:
          let pkg = final.callOpam { inherit name version; } { }; in
          pkg.override { with-test = lib.elem name testablePackages; })
        (solvePackageVersions args);
  };
})
