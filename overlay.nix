final: prev: let
  bootedOcamlPackages = final.ocaml-ng.ocamlPackages_4_14.overrideScope (
    import ./nix/boot/overlay.nix
  );
in {
  opam-nix-integration = final.callPackage ./nix/scope {
    inherit (bootedOcamlPackages) opam2nix;
  };

  opamPackages = final.opam-nix-integration;
}
