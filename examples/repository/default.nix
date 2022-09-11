{ nixpkgs ? fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz"
, opam-repository
}:

let
  opam-nix-integration = import ../..;

  pkgs = import nixpkgs { overlays = [ opam-nix-integration.overlay ]; };

  scope = pkgs.opamPackages.overrideScope' (final: prev: {
    repository = prev.repository.override { src = opam-repository; };
  });

  instantiate = k: v:
    let
      result =
        scope.overrideScope' (final: prev: prev.repository.select {
          packageConstraints = [ "${v.latest.pname} = ${v.latest.version}" ];
        });

      package = result.${k};
    in
    pkgs.runCommand
      v.latest.name
      {
        buildInputs = [ package ];
      }
      ''
        echo $buildInputs > $out
      '';
in

pkgs.lib.attrsets.mapAttrs instantiate scope.repository.packages
