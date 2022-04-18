{ pkgs
, overrideScope'
, repository ? pkgs.callPackage ./opam-repository.nix { }
, packageSelection ? { }
}:

let
  bootPackages = overrideScope' (
    import ./nix/packages/ocaml/overlay.nix
  );

  emptyScope = bootPackages.callPackage ./nix/scope/opam-repository {
    inherit repository;
  };
in

emptyScope.overrideScope' (final: prev: prev.repository.select packageSelection)
