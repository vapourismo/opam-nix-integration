final: prev: {
  zeroinstall-solver = final.callPackage ./packages/0install-solver.nix {};
  opam-0install = final.callPackage ./packages/opam-0install.nix {};
  opam2nix = final.callPackage ./packages/opam2nix.nix {};
}
