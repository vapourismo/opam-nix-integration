{ pkgs
, stdenv
, lib
, newScope
, runCommand
, writeText
, gnumake
, git
, which
, ocaml
, findlib
, opam-installer
, opam2nix
, opamvars2nix
, opamsubst2nix
}@args:

let
  callPackage = lib.callPackageWith args;

  baseScope = callPackage ./base.nix { };
in

baseScope.overrideScope' (final: prev: {
  mkOpam2NixPackage = callPackage ../make-package.nix { } final;

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

  callOpam2Nix = args: final.callPackage (final.generateOpam2Nix args);
})
