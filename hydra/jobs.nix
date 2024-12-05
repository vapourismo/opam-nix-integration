{
  nixpkgs ? fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz",
  opam-nix-integration ? ./..,
  opam-repository ? fetchTarball "https://github.com/ocaml/opam-repository/archive/refs/heads/master.tar.gz",
  prefix ? "",
  ...
}: let
  pkgs = import nixpkgs {
    overlays = [
      # Bring in opam-nix-integration.
      (import opam-nix-integration).overlay

      # Override the default opam-repository.
      (final: prev: {
        opamPackages = prev.opamPackages.overrideScope (final: prev: {
          repository = prev.repository.override {
            src = opam-repository;
          };
        });
      })
    ];
  };

  mkPackage = name: version:
    (
      pkgs.opamPackages.overrideScope (
        final: prev:
          prev.repository.select {
            packageConstraints = [
              "${name} = ${version}"
            ];
          }
      )
    )
    .${name};

  packageNames = pkgs.lib.attrNames pkgs.opamPackages.repository.packages;

  fixName = pkgs.lib.strings.replaceStrings ["."] ["_"];

  flattenAttrs = pkgs.lib.attrsets.concatMapAttrs (_: v: v);

  versions = flattenAttrs (
    pkgs.lib.attrsets.genAttrs
    (
      pkgs.lib.lists.filter
      (name: pkgs.lib.strings.hasPrefix prefix (pkgs.lib.strings.toLower name))
      packageNames
    )
    (
      name: let
        versions = pkgs.lib.lists.remove "latest" (
          pkgs.lib.attrNames pkgs.opamPackages.repository.packages.${name}
        );
      in
        pkgs.lib.attrsets.mapAttrs'
        (version: value: {
          name = fixName "${name}-${version}";
          inherit value;
        })
        (pkgs.lib.attrsets.genAttrs versions (mkPackage name))
    )
  );
in
  versions
