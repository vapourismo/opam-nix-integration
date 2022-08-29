final: prev: {
  zeroinstall-solver = final.callPackage ./0install-solver.nix { };
  opam-0install = final.callPackage ./opam-0install.nix { };
  nix = final.callPackage ./nix.nix { };
  opam2nix = final.callPackage ./opam2nix.nix { };
  opamvars2nix = final.callPackage ./opamvars2nix.nix { };
  opamsubst2nix = final.callPackage ./opamsubst2nix.nix { };
  opam0install2nix = final.callPackage ./opam0install2nix.nix { };
}
