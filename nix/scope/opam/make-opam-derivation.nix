{ pkgs
, stdenv
, lib
, runCommand
, writeText
, writeScript
, opamvars2nix
, opamsubst2nix
, opam-installer
}@args:

let
  callPackage = lib.callPackageWith args;

  extraLib = callPackage ../../lib { };
in

ocamlPackages:

{ name
, version
, src ? null
, buildScript ? [ ]
, installScript ? [ ]
, testScript ? [ ]
, depends ? (_: [ ])
, optionalDepends ? (_: [ ])
, nativeDepends ? [ ]
, extraFiles ? [ ]
, substFiles ? [ ]
, jobs ? 1
, with-test ? false
, with-doc ? false
, patches ? [ ]
, ...
}@args:

let
  opamLib = extraLib.makeOpamLib {
    inherit name version ocamlPackages jobs with-doc with-test;
  };

  opamTestLib = extraLib.makeOpamLib {
    inherit name version ocamlPackages jobs with-doc;
    with-test = true;
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
      [ "ocaml" ] ++ args
    else
      args;

  renderedBuildScript = opamLib.commands.render (
    builtins.map
      (cmd: fixNakedOcamlScript (fixTopkgCommand cmd))
      (opamLib.commands.eval buildScript)
  );

  renderedInstallScript = opamLib.commands.render (opamLib.commands.eval installScript);

  renderedTestScript = opamLib.commands.render (opamLib.commands.eval testScript);

  overlayedSource = opamLib.source.fix { inherit name version src extraFiles substFiles; };

  setupHookDeriv = stdenv.mkDerivation {
    name = "ocaml-setup-hook";

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out
    '';

    setupHook = writeScript "setup-hook.sh" ''
      function addOCamlPath {
        if test -d "''$1/lib"; then
          export OCAMLPATH="''${OCAMLPATH-}''${OCAMLPATH:+:}''$1/lib"
        fi

        if test -d "''$1/lib/stublibs"; then
          export CAML_LD_LIBRARY_PATH="''${CAML_LD_LIBRARY_PATH-}''${CAML_LD_LIBRARY_PATH:+:}''$1/lib/stublibs"
        fi
      }

      addEnvHooks "$targetOffset" addOCamlPath

      function exportOcamlDestDir {
        export OCAMLFIND_DESTDIR="''$out/lib"
      }

      addEnvHooks "$hostOffset" exportOcamlDestDir

      function createOcamlDestDir {
        if test -n "''${createFindlibDestdir-}"; then
          mkdir -p $OCAMLFIND_DESTDIR
        fi
      }

      preInstallHooks+=(createOcamlDestDir)
    '';
  };

  selectedPatches =
    builtins.map
      ({ path, ... }: "${overlayedSource}/${path}")
      (builtins.filter ({ filter, ... }: opamLib.filter.eval filter) patches);
in

stdenv.mkDerivation ({
  pname = name;
  version = extraLib.cleanVersion version;

  src = overlayedSource;

  patches = lib.optionals (name == "ocamlfind") [
    ./topfind.patch
    ./ldconf.patch
  ] ++ selectedPatches;

  buildInputs = with pkgs; [ git which ];

  propagatedBuildInputs =
    # We want to propagate 'ocamlfind' to everything that uses 'dune'. Dune does not behave
    # correctly for us when 'ocamlfind' can't be found by it.
    [ setupHookDeriv ]
      ++ lib.optional (name == "dune") ocamlPackages.ocamlfind
      ++ opamLib.depends.eval { inherit name; } depends
      ++ opamLib.depends.eval { inherit name; optional = true; } optionalDepends;

  propagatedNativeBuildInputs = opamLib.depends.evalNative nativeDepends;

  checkInputs =
    opamTestLib.depends.eval { inherit name; } depends
      ++ opamTestLib.depends.eval { inherit name; optional = true; } optionalDepends
      ++ opamTestLib.depends.evalNative nativeDepends;

  dontConfigure = true;

  buildPhase = ''
    # Build Opam package
    ${renderedBuildScript}
  '';

  installPhase = ''
    # Install Opam package
    mkdir -p ${opamLib.env.local.bin} ${opamLib.env.local.lib}
    export DUNE_INSTALL_PREFIX=$out
    ${defaultInstallScript}
    ${renderedInstallScript}
  '';

  doCheck = with-test;

  checkPhase = ''
    # Test Opam package
    ${renderedTestScript}
  '';
} // builtins.removeAttrs args [
  "name"
  "version"
  "src"
  "buildScript"
  "installScript"
  "testScript"
  "depends"
  "optionalDepends"
  "nativeDepends"
  "extraFiles"
  "substFiles"
  "patches"
])
