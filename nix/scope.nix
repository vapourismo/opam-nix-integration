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

in
lib.makeScope newScope (self: {
  ocaml = ocaml.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ makeWrapper ];

    postInstall = ''
      ${old.postInstall or ""}
      wrapProgram "$out/bin/ocaml" --add-flags "-I ${findlib}/lib/ocaml/${ocaml.version}/site-lib"
    '';
  });

  ocamlfind = findlib;

  mkOpam2NixPackage = callPackage ./make-package.nix {
    inherit (self) opamvars2nix;
    ocamlPackages = self;
  };

  opam2nix = justExecutable (import ../default.nix).default;

  opamvars2nix = justExecutable (import ../default.nix).packages.${system}.opamvars2nix;

  opamsubst2nix = justExecutable (import ../default.nix).packages.${system}.opamsubst2nix;

  generateOpam2Nix = { name, version, src, patches ? [ ] }:
    import (
      runCommand
        "opam2nix-${name}-${version}"
        {
          buildInputs = [ self.opam2nix ];
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

  callOpam2Nix = args: self.callPackage (self.generateOpam2Nix args);

  callOpam = { name, version, patches ? [ ] }:
    let
      src = "${opamRepository}/packages/${name}/${name}.${version}/opam";
    in
    args: self.callOpam2Nix { inherit name version src patches; } ({
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
                value = self.callOpam { inherit name version; } { };
              })
              versions
          ) // {
          latest = self.callOpam { inherit name; version = repoInfo.latest name; } { };
        })
      repoInfo.versions;
})
