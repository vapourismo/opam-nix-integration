{ callPackage
, stdenv
, runCommand
, system
, lib
, newScope
, ocaml
, findlib
, makeWrapper
, opamRepository ? callPackage ./repository.nix { }
}:

let
  repoInfo = import ./repository-info.nix {
    inherit lib opamRepository;
  };

  justExecutable = deriv: stdenv.mkDerivation {
    inherit (deriv) pname version;

    phases = [ "installPhase" ];

    installPhase = ''
      mkdir $out
      cp -r ${deriv}/bin $out
    '';
  };

  opam2NixFlake = import ../default.nix;

  baseScope = callPackage ./scope/base.nix {
    inherit ocaml findlib;
  };

in
baseScope.overrideScope' (final: prev: {
  mkOpam2NixPackage = callPackage ./make-package.nix {
    inherit (final) opamvars2nix opamsubst2nix;
    ocamlPackages = final;
  };

  opam2nix = justExecutable opam2NixFlake.packages.${system}.opam2nix;

  opamvars2nix = justExecutable opam2NixFlake.packages.${system}.opamvars2nix;

  opamsubst2nix = justExecutable opam2NixFlake.packages.${system}.opamsubst2nix;

  generateOpam2Nix = { name, version, src, patches ? [ ] }:
    import (
      runCommand
        "opam2nix-${name}-${version}"
        {
          buildInputs = [ final.opam2nix ];
          inherit src patches;
        }
        ''
          cp $src opam
          chmod +w opam
          for patch in $patches; do
            patch opam $patch
          done
          opam2nix --name ${name} --version ${version} --file opam > $out
        ''
    );

  callOpam2Nix = args: final.callPackage (final.generateOpam2Nix args);

  callOpam = { name, version, patches ? [ ] }:
    let
      src = "${opamRepository}/packages/${name}/${name}.${version}/opam";
    in
    args: final.callOpam2Nix { inherit name version src patches; } ({
      resolveExtraFile = { path, ... }@args: {
        inherit path;
        source = "${opamRepository}/packages/${name}/${name}.${version}/files/${path}";
      };
    } // args);

  opamPackages =
    builtins.mapAttrs
      (name: versions:
        builtins.listToAttrs
          (
            builtins.map
              (version: {
                name = version;
                value = final.callOpam { inherit name version; } { };
              })
              versions
          ) // {
          latest = final.callOpam { inherit name; version = repoInfo.latest name; } { };
        })
      repoInfo.versions;
})
