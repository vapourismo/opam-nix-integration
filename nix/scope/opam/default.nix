{ pkgs
, stdenv
, lib
, system
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
in

lib.makeScope pkgs.newScope (self: {
  mkOpamDerivation = callPackage ./make-opam-derivation.nix { } self;

  selectOpamSrc = src: altSrc: if altSrc != null then altSrc else src;

  resolveOpamExtraSrc = extraSrc: file:
    if builtins.isPath extraSrc || builtins.isString extraSrc then
      "${extraSrc}/${file}"
    else
      abort "OPAM file needs 'extraSrc' to be a string or path! Got: ${builtins.typeOf extraSrc}";

  generateOpam2Nix = { name, version, opam, patches ? [ ] }:
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
            --file opam > $out
        ''
    );

  callOpam2Nix = { name, opam ? null, src ? null, ... }@args: extra:
    let
      argOverride =
        if opam != null then
          { }
        else if src != null then
          { opam = "${src}/${name}.opam"; }
        else
          abort "'opam' mustn't be null if 'src' is also null!";
    in
    self.callPackage
      (self.generateOpam2Nix (builtins.removeAttrs args [ "src" ] // argOverride))
      ({ altSrc = src; } // extra);
})
