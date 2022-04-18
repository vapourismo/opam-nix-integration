{ callPackage
, overrideScope'
, opamRepository ? callPackage ./opam-repository.nix { }
, packageSelection ? { }
}:

let
  bootPackages = overrideScope' (
    import ./nix/packages/ocaml/overlay.nix
  );

  emptyScope = bootPackages.callPackage ./nix/scope/opam-repository {
    inherit opamRepository;
  };
in

emptyScope.overrideScope' (final: prev: prev.opamRepository.select packageSelection)
