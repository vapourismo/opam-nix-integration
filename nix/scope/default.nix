{
  pkgs,
  stdenv,
  lib,
  system,
  runCommand,
  writeText,
  writeScript,
  gnumake,
  jq,
  unzip,
  git,
  which,
  darwin,
  fixDarwinDylibNames,
  autoPatchelfHook,
  opam-installer,
  opam2nix,
  opamvars2nix,
  opamsubst2nix,
  opam0install2nix,
} @ args: let
  callSubPackage = lib.callPackageWith args;
in
  lib.makeScope pkgs.newScope (final: {
    mkOpamDerivation = callSubPackage ./make-opam-derivation.nix {
      inherit opamvars2nix opamsubst2nix opam-installer;
    };

    selectOpamSrc = src: altSrc:
      if altSrc != null
      then altSrc
      else src;

    callOpam2Nix = callSubPackage ./call-opam2nix.nix {
      inherit opam2nix;
      inherit (final) callPackage;
    };

    repository = callSubPackage ./repository {
      inherit opam0install2nix;
      inherit (final) callOpam2Nix;

      src = runCommand "empty-opam-repository" {} ''
        mkdir -p $out/packages
      '';
    };
  })
