final: prev: {
  zeroinstall-solver = final.callPackage ./packages/0install-solver.nix { };
  opam-0install = final.callPackage ./packages/opam-0install.nix { };
  nix = final.callPackage ./packages/nix.nix { };
  opam2nix = final.callPackage ./packages/opam2nix.nix { };
  opamvars2nix = final.callPackage ./packages/opamvars2nix.nix { };
  opamsubst2nix = final.callPackage ./packages/opamsubst2nix.nix { };
  opam0install2nix = final.callPackage ./packages/opam0install2nix.nix { };
}
