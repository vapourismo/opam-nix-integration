{ pkgs
, stdenv
, lib
, newScope
, runCommand
, writeText
, writeScript
, gnumake
, unzip
, jq
, git
, which
, ocaml
, findlib
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
      testTargetArgs = builtins.map (name: "--with-test-for=${name}") testablePackages;

      versions = import (
        runCommand
          "opam0install2nix-solver"
          {
            buildInputs = [ opam0install2nix ];
            inherit testTargetArgs packageConstraints;
          }
          ''
            opam0install2nix \
              $testTargetArgs \
              --ocaml-version="${ocaml.version}" \
              --packages-dir="${opamRepository}/packages" \
              $packageConstraints \
              > $out
          ''
      );
    in
    lib.filterAttrs (name: _: !(lib.hasAttr name opamScope)) versions;
in

opamScope.overrideScope' (final: prev: {
  callOpam = { name, version, patches ? [ ] }: args:
    final.callOpam2Nix
      {
        inherit name version patches;
        src = "${packagePath name version}/opam";
      }
      (
        {
          resolveExtraFile = { path, ... }@args: {
            inherit path;
            source = "${packagePath name version}/files/${path}";
          };
        }
        // args
      );

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
