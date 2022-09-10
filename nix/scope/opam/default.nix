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
}:

let
  mkCallOpam2Nix = { callPackage, opam2nix }:
    let
      generateOpam2Nix = callPackage ./generate-opam2nix.nix {
        inherit opam2nix;
      };
    in

    { name, opam ? null, src ? null, ... }@args: extra:
      let
        argOverride =
          if opam != null then
            { }
          else if src != null then
            { opam = "${src}/${name}.opam"; }
          else
            abort "'opam' mustn't be null if 'src' is also null!";
      in
      callPackage
        (generateOpam2Nix (builtins.removeAttrs args [ "src" ] // argOverride))
        ({ altSrc = src; } // extra);
in

lib.makeScope pkgs.newScope (final: {
  mkOpamDerivation = final.callPackage ./make-opam-derivation.nix {
    inherit opamvars2nix opamsubst2nix opam-installer;
  };

  selectOpamSrc = src: altSrc: if altSrc != null then altSrc else src;

  callOpam2Nix = final.callPackage mkCallOpam2Nix {
    inherit opam2nix;
  };
})
