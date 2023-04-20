{
  callPackage,
  lib,
  runCommand,
  opam2nix,
}: let
  generateOpam2Nix = import ./generate-opam2nix.nix {
    inherit lib runCommand opam2nix;
  };

  inferOpamLocation = import ./infer-opam-location.nix;
in
  {src ? null, ...} @ args: extra:
    callPackage
    (generateOpam2Nix (builtins.removeAttrs (inferOpamLocation args) ["src"]))
    ({altSrc = src;} // extra)
