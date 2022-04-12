{ pkgs
, stdenv
, lib
, runCommand
, writeText
, gnumake
, git
, opamvars2nix
, opamsubst2nix
, opam-installer
}@args:

let
  callPackage = lib.callPackageWith args;

  ocamlLib = callPackage ./lib.nix { };
in

ocamlPackages:

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
  evalLib = ocamlLib.makeEvalLib { inherit name version ocamlPackages; };

  opam =
    callPackage ./opam.nix
      { }
      {
        inherit ocamlPackages;
        envLib = evalLib.env;
        filterLib = evalLib.filter;
        constraintLib = evalLib.constraint;
        formulaLib = evalLib.formula;
      };

  defaultInstallScript = ''
    if test -r "${name}.install"; then
      ${opam-installer}/bin/opam-installer \
        --prefix="${evalLib.env.local.prefix}" \
        --libdir="${evalLib.env.local.lib}" \
        --docdir="${evalLib.env.local.doc}" \
        --mandir="${evalLib.env.local.man}" \
        --name="${name}" \
        --install "${name}.install"
    fi
  '';

  fixTopkgCommand = args:
    # XXX: A hack to deal with missing 'topfind' dependency for 'topkg'-based packages.
    if lib.lists.take 2 args == [ "\"ocaml\"" "\"pkg/pkg.ml\"" ] then
      [
        "ocaml"
        "-I"
        "${ocamlPackages.ocamlfind}/lib/ocaml/${ocamlPackages.ocaml.version}/site-lib"
      ] ++ lib.lists.drop 1 args
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
    name = "opam2nix-extra-files-${name}-${ocamlLib.cleanVersion version}";

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
  version = ocamlLib.cleanVersion version;

  src = overlayedSource;

  buildInputs = with ocamlPackages; [ ocaml ocamlfind git ];

  propagatedBuildInputs =
    opam.evalDependenciesFormula { inherit name; } depends
      ++ opam.evalDependenciesFormula { inherit name; optional = true; } optionalDepends;

  propagatedNativeBuildInputs = opam.evalNativeDependencies nativeDepends;

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
    mkdir -p ${evalLib.env.local.bin} ${evalLib.env.local.lib}
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
