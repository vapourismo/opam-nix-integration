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
} @ args: let
  callSubPackage = lib.callPackageWith args;
in
  lib.makeScope pkgs.newScope (final: {
    mkOpamDerivation = callSubPackage ./make-opam-derivation.nix {
      inherit opam2nix opam-installer;
    };

    callOpam2Nix = callSubPackage ./call-opam2nix.nix {
      inherit opam2nix;
      inherit (final) callPackage;
    };

    repository = callSubPackage ./repository {
      inherit opam2nix;
      inherit (final) callOpam2Nix;

      src = runCommand "empty-opam-repository" {} ''
        mkdir -p $out/packages
      '';
    };
  })
