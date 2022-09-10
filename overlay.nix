final: prev:

let
  bootedOcamlPackages = final.ocaml-ng.ocamlPackages_4_14.overrideScope' (
    import ./nix/boot/overlay.nix
  );
in

{
  opam-nix-integration = {
    emptyRepository = final.runCommand "empty-opam-repository" { } ''
      mkdir -p $out/packages
    '';

    emptyPackageSet =
      final.callPackage
        ./nix/scope/opam-repository
        {
          inherit (bootedOcamlPackages) opam2nix opamvars2nix opamsubst2nix opam0install2nix;
          repository = final.opam-nix-integration.emptyRepository;
        };

    makePackageSet = { repository, packageSelection ? { }, overlays ? [ ] }:
      let
        repoScope = final.opam-nix-integration.emptyPackageSet.override {
          inherit repository;
        };

        selectionOverride = final: prev: prev.repository.select packageSelection;
      in
      repoScope.overrideScope' (
        final.lib.composeManyExtensions ([ selectionOverride ] ++ overlays)
      );
  };
}
