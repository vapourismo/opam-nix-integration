{ pkgs
, callPackage
, runCommand
, writeText
, lib
, stdenv
, ocamlPackages
, gnumake
, opamvars2nix
, opamsubst2nix
, opam-installer
, git
}:

{ name
, version
, src ? null
, buildScript ? [ ]
, installScript ? [ ]
, depends ? (_: [ ])
, optionalDepends ? (_: [ ])
, nativeDepends ? [ ]
, extraFiles ? [ ]
, substFiles ? [ ]
, ...
}@args:

let
  envLib =
    callPackage ./eval/env.nix
      { inherit opamvars2nix ocamlPackages; }
      { inherit name version; };

  filterLib = callPackage ./eval/filter.nix { } { inherit envLib; };

  constraintLib = import ./eval/constraint.nix { inherit filterLib; };

  formulaLib = import ./eval/formula.nix;

  opam = callPackage ./opam.nix { } { inherit envLib filterLib constraintLib formulaLib; };

  defaultInstallScript = ''
    if test -r "${name}.install"; then
      ${opam-installer}/bin/opam-installer \
        --prefix="${envLib.local.prefix}" \
        --libdir="${envLib.local.lib}" \
        --docdir="${envLib.local.doc}" \
        --mandir="${envLib.local.man}" \
        --name="${name}" \
        --install "${name}.install"
    fi
  '';

  fixTopkgCommand = args:
    # XXX: A hack to deal with missing 'topfind' dependency for 'topkg'-based packages.
    if lib.lists.take 2 args == [ "\"ocaml\"" "\"pkg/pkg.ml\"" ] then
      [ "ocaml" "-I" envLib.packages.ocamlfind.lib ] ++ lib.lists.drop 1 args
    else
      args;

  renderCommands = cmds: builtins.concatStringsSep "\n" (
    builtins.map (builtins.concatStringsSep " ") cmds
  );

  renderedBuildScript = renderCommands (
    builtins.map fixTopkgCommand (opam.evalCommands buildScript)
  );

  renderedInstallScript = renderCommands (opam.evalCommands installScript);

  copyExtraFiles = builtins.concatStringsSep "\n" (
    builtins.map ({ source, path }: "cp ${source} ${path}") extraFiles
  );

  overlayedSource = stdenv.mkDerivation {
    name = "opam2nix-extra-files-${name}-${opam.cleanVersion version}";

    inherit src;
    dontUnpack = src == null;

    phases = [ "unpackPhase" "installPhase" ];

    installPhase = ''
      mkdir -p $out
      ${copyExtraFiles}
      cp -r . $out
    '';
  };

  substs = builtins.map
    (file:
      {
        path = file;
        source = writeText "opam2nix-subst-file" (opam.interpolate (import (
          runCommand
            "opam2nix-subst-expr"
            {
              buildInputs = [ opamsubst2nix ];
            }
            "opamsubst2nix < ${overlayedSource}/${file}.in > $out"
        )));
      }
    )
    substFiles;

  writeSubsts = builtins.concatStringsSep "\n" (
    builtins.map
      ({ path, source }: "cp -v ${source} ${path}")
      substs
  );

in
stdenv.mkDerivation ({
  pname = name;
  version = opam.cleanVersion version;

  src = overlayedSource;

  buildInputs = with ocamlPackages; [ ocaml ocamlfind git ];

  propagatedBuildInputs =
    opam.evalDependenciesFormula name ocamlPackages depends
      ++ opam.evalDependenciesFormula name ocamlPackages optionalDepends;

  propagatedNativeBuildInputs = opam.evalNativeDependencies pkgs nativeDepends;

  dontConfigure = true;

  patchPhase = ''
    ${writeSubsts}
  '';

  buildPhase = ''
    # Build Opam package
    ${renderedBuildScript}
  '';

  installPhase = ''
    # Install Opam package
    mkdir -p ${envLib.local.bin} ${envLib.local.lib}
    ${defaultInstallScript}
    ${renderedInstallScript}
  '';
} // builtins.removeAttrs args [
  "name"
  "version"
  "src"
  "buildScript"
  "installScript"
  "depends"
  "optionalDepends"
  "nativeDepends"
  "extraFiles"
  "substFiles"
])
