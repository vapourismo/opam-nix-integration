{
  nixpkgs,
  opam-nix-integration,
  opam-repository,
  name,
  ...
}: let
  pkgs = import nixpkgs {
    overlays = [
      # Bring in opam-nix-integration.
      (import opam-nix-integration).overlay

      # Override the default opam-repository.
      (final: prev: {
        opamPackages = prev.opamPackages.overrideScope' (final: prev: {
          repository = prev.repository.override {
            src = opam-repository;
          };
        });
      })
    ];
  };

  mkPackage = name: version:
    (
      pkgs.opamPackages.overrideScope' (
        final: prev:
          prev.repository.select {
            packageConstraints = [
              "${name} = ${version}"
            ];
          }
      )
    )
    .${name};

  fixName = pkgs.lib.strings.replaceStrings ["."] ["_"];

  versions = let
    versions = pkgs.lib.lists.remove "latest" (
      pkgs.lib.attrNames pkgs.opamPackages.repository.packages.${name}
    );
  in
    pkgs.lib.attrsets.mapAttrs'
    (version: value: {
      name = fixName "${name}-${version}";
      inherit value;
    })
    (pkgs.lib.attrsets.genAttrs versions (mkPackage name));
in
  versions
