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
, opamRepository
}@args:

let
  callPackage = lib.callPackageWith args;

  opamScope = callPackage ../opam { };

  repositoryIndex = callPackage ./repository-index.nix { } opamRepository;

  packagePath = name: version: "${opamRepository}/packages/${name}/${name}.${version}";

  solvePackageVersions =
    { packageConstraints ? [ ]
    , testablePackages ? [ ]
    }:
    let
      testTargetArgs = lib.strings.escapeShellArgs (
        builtins.map (name: "--with-test-for=${name}") testablePackages
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
              --packages-dir="${opamRepository}/packages" \
              ${testTargetArgs} \
              ${packageConstraintArgs} \
              > $out
          ''
      );
    in
    versions;
in

opamScope.overrideScope' (final: prev: {
  callOpam = { name, version, patches ? [ ] }:
    final.callOpam2Nix {
      inherit name version patches;
      opam = "${packagePath name version}/opam";
      extraSrc = "${packagePath name version}/files";
    };

  opamRepository = {
    packages =
      builtins.mapAttrs
        (name: collection:
          builtins.listToAttrs
            (
              builtins.map
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
      builtins.mapAttrs
        (name: version:
          let pkg = final.callOpam { inherit name version; } { }; in
          pkg.overrideAttrs (_: { doCheck = lib.elem name testablePackages; }))
        (solvePackageVersions args);
  };
})
