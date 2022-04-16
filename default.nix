{ overrideScope', opamRepository }:

let
  bootPackages = overrideScope' (
    import ./nix/packages/ocaml/overlay.nix
  );
in

bootPackages.callPackage ./nix/scope/opam-repository {
  inherit opamRepository;
}
