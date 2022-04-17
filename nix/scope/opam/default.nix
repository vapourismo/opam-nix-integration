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
}@args:

let
  callPackage = lib.callPackageWith args;

  baseScope = callPackage ../base { };
in

baseScope.overrideScope' (final: prev: {
  mkOpam2NixPackage = callPackage ./make-package.nix { } final;

  generateOpam2Nix = { name, version, src, patches ? [ ] }:
    import (
      runCommand
        "opam2nix-${name}-${version}"
        {
          buildInputs = [ opam2nix ];
          inherit src patches;
        }
        ''
          cp $src opam
          chmod +w opam
          for patch in $patches; do
            patch opam $patch
          done
          opam2nix --name ${name} --version ${version} --file opam > $out
        ''
    );

  callOpam2Nix = args: extra:
    final.callPackage (final.generateOpam2Nix args) ({
      resolveExtraFile = { path, ... }: {
        inherit path;
        source = "${builtins.dirOf args.src}/files/${path}";
      };

      altSrc = builtins.dirOf args.src;
    } // extra);
})
