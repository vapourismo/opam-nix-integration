{ callPackage, lib, runCommand, opam2nix }:

let
  generateOpam2Nix = import ./generate-opam2nix.nix {
    inherit lib runCommand opam2nix;
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
  ({ altSrc = src; } // extra)
