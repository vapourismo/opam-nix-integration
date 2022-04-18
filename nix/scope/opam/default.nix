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
  mkOpamDerivation = callPackage ./make-opam-derivation.nix { } final;

  generateOpam2Nix = { name, version, opam, src ? null, extraSrc ? null, patches ? [ ] }:
    import (
      runCommand
        "opam2nix-${name}-${version}"
        {
          buildInputs = [ opam2nix ];
          inherit opam patches;
        }
        ''
          cp $opam opam
          chmod +w opam
          for patch in $patches; do
            patch opam $patch
          done
          opam2nix \
            --name ${name} \
            --version ${version} \
            ${lib.optionalString (src != null) "--source ${src}"} \
            ${lib.optionalString (extraSrc != null) "--extra-source ${extraSrc}"} \
            --file opam > $out
        ''
    );

  callOpam2Nix = { name, opam ? null, src ? null, ... }@args:
    let
      extraArgs =
        if opam != null then
          { }
        else if src != null then
          { opam = "${src}/${name}.opam"; }
        else
          abort "'opam' mustn't be null if 'src' is also null!";
    in
    final.callPackage (final.generateOpam2Nix (args // extraArgs));
})
