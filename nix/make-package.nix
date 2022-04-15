{ pkgs
, stdenv
, lib
, runCommand
, writeText
, writeScript
, gnumake
, git
, which
, opamvars2nix
, opamsubst2nix
, opam-installer
}@args:

let
  callPackage = lib.callPackageWith args;

  extraLib = callPackage ./lib { };
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
  opamLib = extraLib.makeOpamLib { inherit name version ocamlPackages; };

  opam = callPackage ./opam.nix { } {
    inherit ocamlPackages;
    envLib = opamLib.env;
    filterLib = opamLib.filter;
    constraintLib = opamLib.constraint;
    formulaLib = opamLib.formula;
  };

  defaultInstallScript = ''
    if test -r "${name}.install"; then
      ${opam-installer}/bin/opam-installer \
        --prefix="${opamLib.env.local.prefix}" \
        --name="${name}" \
        --install "${name}.install"
    fi
  '';

  fixTopkgCommand = args:
    # XXX: A hack to deal with missing 'topfind' dependency for 'topkg'-based packages.
    if lib.lists.take 2 args == [ "ocaml" "pkg/pkg.ml" ] then
      [
        "ocaml"
        "-I"
        "${ocamlPackages.ocamlfind}/lib"
      ] ++ lib.lists.drop 1 args
    else
      args;

  fixNakedOcamlScript = args:
    # XXX: Hack to patch invocation of OCaml scripts that rely on shebang.
    if lib.lists.length args > 0 && lib.strings.hasSuffix ".ml" (lib.lists.elemAt args 0) then
      [ "${ocamlPackages.ocaml}/bin/ocaml" ] ++ args
    else
      args;

  renderCommands = cmds: builtins.concatStringsSep "\n" (
    builtins.map (args: builtins.concatStringsSep " " (builtins.map builtins.toJSON args)) cmds
  );

  renderedBuildScript = renderCommands (
    builtins.map (cmd: fixNakedOcamlScript (fixTopkgCommand cmd)) (opam.evalCommands buildScript)
  );

  renderedInstallScript = renderCommands (opam.evalCommands installScript);

  copyExtraFiles = builtins.concatStringsSep "\n" (
    builtins.map ({ source, path }: "cp ${source} ${path}") extraFiles
  );

  fixCargoChecksums = writeScript "fix-cargo-checksum" ''
    jq "{ package: .package, files: { } }" "$1" > "$1.empty"
    mv "$1.empty" "$1"
  '';

  overlayedSource = stdenv.mkDerivation {
    name = "opam2nix-extra-files-${name}-${extraLib.cleanVersion version}";

    inherit src;
    dontUnpack = src == null;

    setSourceRoot = ''
      export sourceRoot="$(find . -type d -mindepth 1 -maxdepth 1 ! -name env-vars)"

      # If the unpack command creates multiple directories we'll choose the most top-level directory
      # as our source root.
      if [[ $(echo "$sourceRoot" | wc -l) -gt 1 ]]; then
        export sourceRoot="."
      fi
    '';

    buildInputs = with pkgs; [ unzip jq ];

    phases = [ "unpackPhase" "installPhase" ];

    installPhase = ''
      mkdir -p $out

      # Resolve extra files
      ${copyExtraFiles}

      # Copy local source over
      cp -r . $out

      # Patch shebangs in shell scripts
      patchShebangsAuto

      # Fix Cargo checksum files
      find $out -name .cargo-checksum.json -exec ${fixCargoChecksums} {} \;
    '';
  };

  substs =
    builtins.map
      (file: {
        path = file;
        source = writeText "opam2nix-subst-file" (opam.interpolate (import (
          runCommand
            "opam2nix-subst-expr"
            {
              buildInputs = [ opamsubst2nix ];
            }
            "opamsubst2nix < ${overlayedSource}/${file}.in > $out"
        )));
      })
      substFiles;

  writeSubsts = builtins.concatStringsSep "\n" (
    builtins.map
      ({ path, source }: "cp -v ${source} ${path}")
      substs
  );

in
stdenv.mkDerivation ({
  pname = name;
  version = extraLib.cleanVersion version;

  src = overlayedSource;

  buildInputs = [ git which ];

  propagatedBuildInputs =
    (with ocamlPackages; [ ocaml ocamlfind ])
      ++ opam.evalDependenciesFormula { inherit name; } depends
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
    mkdir -p ${opamLib.env.local.bin} ${opamLib.env.local.lib}
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
