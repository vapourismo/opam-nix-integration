{
  nixpkgs,
  opam-nix-integration,
  opam-repository,
}: let
  pkgs = import nixpkgs {
    overlays = [
      (import opam-nix-integration).overlay
      (final: prev: {
        opam-nix-integration = prev.opam-nix-integration.overrideScope' (final: prev: {
          repository = prev.repository.override {src = opam-repository;};
        });
      })
    ];
  };
in {
  jobsets = pkgs.writeText "jobsets.json" (
    builtins.toJSON (
      import ./jobsets.nix pkgs
    )
  );
}
