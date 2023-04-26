{nixpkgs}: let
  pkgs = import nixpkgs {};
in {
  jobsets = pkgs.writeText "jobsets.json" (
    builtins.toJSON (
      import ./jobsets.nix pkgs
    )
  );
}
