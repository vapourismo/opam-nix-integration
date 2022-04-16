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
, packageConstraints ? [ ]
}@args:

let
  callPackage = lib.callPackageWith args;

  opamScope = callPackage ../opam { };

  # repositoryIndex = callPackage ./repository-index.nix { } opamRepository;

  packagePath = name: version: "${opamRepository}/packages/${name}/${name}.${version}";

  selectedPackageVersions =
    let
      versions = import (
        runCommand
          "opam0install2nix-solver"
          {
            buildInputs = [ opam0install2nix ];
            inherit packageConstraints;
          }
          ''
            opam0install2nix \
              --ocaml-version="${ocaml.version}" \
              --packages-dir="${opamRepository}/packages" \
              $packageConstraints \
              > $out
          ''
      );
    in
    prev: lib.filterAttrs (name: _: !(lib.elem name (lib.attrNames prev))) versions;

  selectedPackages = final: prev:
    builtins.mapAttrs
      (name: version: final.callOpam { inherit name version; } { })
      (selectedPackageVersions prev);

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

  # opamRepository =
  #   builtins.mapAttrs
  #     (name: collection:
  #       builtins.listToAttrs
  #         (
  #           builtins.map
  #             (version: {
  #               name = version;
  #               value = final.callOpam { inherit name version; } { };
  #             })
  #             collection.versions
  #         ) // {
  #         latest =
  #           final.callOpam
  #             { inherit name; version = collection.latest; }
  #             { };
  #       })
  #     repositoryIndex;
} // selectedPackages final prev)
