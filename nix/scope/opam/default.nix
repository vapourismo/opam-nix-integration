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

lib.makeScope pkgs.newScope (self: {
  mkOpamDerivation = self.callPackage ./make-opam-derivation.nix {
    inherit opamvars2nix opamsubst2nix opam-installer;
  };

  selectOpamSrc = src: altSrc: if altSrc != null then altSrc else src;

  generateOpam2Nix = self.callPackage ./generate-opam2nix.nix {
    inherit opam2nix;
  };

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
