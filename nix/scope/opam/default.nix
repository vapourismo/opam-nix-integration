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

lib.makeScope pkgs.newScope (final: {
  mkOpamDerivation = final.callPackage ./make-opam-derivation.nix {
    inherit opamvars2nix opamsubst2nix opam-installer;
  };

  selectOpamSrc = src: altSrc: if altSrc != null then altSrc else src;

  callOpam2Nix = final.callPackage ./call-opam2nix.nix { inherit opam2nix; };
})
