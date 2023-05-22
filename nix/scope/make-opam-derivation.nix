{
  stdenv,
  lib,
  runCommand,
  writeText,
  writeScript,
  opam2nix,
  opam-installer,
  gnumake,
  jq,
  unzip,
  git,
  which,
  darwin,
  fixDarwinDylibNames,
  autoPatchelfHook,
} @ args: let
  extraLib = lib.callPackageWith args ../lib {};
in
  {
    name,
    version,
    src ? null,
    buildScript ? [],
    installScript ? [],
    testScript ? [],
    depends ? (_: []),
    optionalDepends ? (_: []),
    nativeDepends ? [],
    guessedNativeDepends ? [],
    extraFiles ? [],
    substFiles ? [],
    substEnv ? {},
    jobs ? "$NIX_BUILD_CORES",
    with-test ? false,
    with-doc ? false,
    patches ? [],
    ...
  } @ args: let
    ocamlPackages = lib.attrsets.filterAttrs (_: v: v != null) substEnv;

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

    fixMachOLibsScript = ''
      fixMachOSharedObjects() {
        local flags=()

        for fn in "$@"; do
            flags+=(-change "$(basename "$fn")" "$fn")
        done

        for fn in "$@"; do
            if [ -L "$fn" ]; then continue; fi
            echo "$fn: fixing dylib"
            install_name_tool -id "$fn" "''${flags[@]}" "$fn"
        done
      }

      fixMachOSharedObjects $(find ${opamLib.env.local.lib} \( -iname '*.so' -or -iname '*.dylib' \))
    '';

    linkRelativeScript = writeScript "link-relative" ''
      target=$1
      base=$2
      source=$3

      link=$target/$(realpath --relative-to=$base $source)
      mkdir -p $(dirname $link)
      ln -fsv $source $link
    '';

    fixBadInstallsScript = ''
      # Some packages install the shared libraries into the 'lib' directory, where they won't be
      # found. So we link them.
      mkdir -p ${opamLib.env.packages."_".stublibs}
      find ${opamLib.env.local.lib} \
        \( -iname '*.so' -or -iname '*.a' -or -iname '*.dylib' -or -iname '*.dll' \) \
        -type f \
        -exec ln -fsvt ${opamLib.env.packages."_".stublibs} {} \;
      if test -z "$(ls -A ${opamLib.env.packages."_".stublibs})"; then
        rm -r ${opamLib.env.packages."_".stublibs}
      fi

      # Find and install header files.
      mkdir -p $out/include
      if test -d "${opamLib.env.packages."_".lib}"; then
        find ${opamLib.env.packages."_".lib} \
          \( -iname '*.h' -or -iname '*.hpp' -or -iname '*.hxx' -or -iname '*.hh' \) \
          -type f \
          -exec ${linkRelativeScript} $out/include ${opamLib.env.packages."_".lib} {} \;
      fi
      if test -z "$(ls -A $out/include)"; then
        rm -r $out/include
      fi

      ${lib.optionalString stdenv.isDarwin fixMachOLibsScript}
    '';

    # XXX: A hack to deal with missing 'topfind' dependency for 'topkg'-based packages.
    fixTopkgCommand = args:
      if lib.lists.take 2 args == ["ocaml" "pkg/pkg.ml"] && lib.hasAttr "ocamlfind" ocamlPackages
      then
        [
          "ocaml"
          "-I"
          "${ocamlPackages.ocamlfind}/lib"
        ]
        ++ lib.lists.drop 1 args
      else args;

    # XXX: Hack to patch invocation of OCaml scripts that rely on shebang.
    fixNakedOcamlScript = args:
      if lib.lists.length args > 0 && lib.strings.hasSuffix ".ml" (lib.lists.elemAt args 0)
      then ["ocaml"] ++ args
      else args;

    # XXX: Manually installs 'topfind'.
    extraOcamlfindInstallScript = ''
      install -c src/findlib/topfind $OCAMLFIND_DESTDIR
    '';

    renderedBuildScript = opamLib.commands.render (
      lib.lists.map
      (cmd: fixNakedOcamlScript (fixTopkgCommand cmd))
      (opamLib.commands.eval buildScript)
    );

    renderedInstallScript = opamLib.commands.render (opamLib.commands.eval installScript);

    renderedTestScript = opamLib.commands.render (opamLib.commands.eval testScript);

    writeSetupHookScript = ''
      mkdir -p $out/nix-support

      # Make this package discoverable as a OCaml dependency.
      if test -d "${opamLib.env.local.lib}"; then
        echo "export OCAMLPATH=\"\''${OCAMLPATH-}\''${OCAMLPATH:+:}${opamLib.env.local.lib}\"" >> $out/nix-support/setup-hook
      fi

      # Expose libraries if there are any.
      if test -d "${opamLib.env.packages."_".stublibs}"; then
        echo "export CAML_LD_LIBRARY_PATH=\"\''${CAML_LD_LIBRARY_PATH-}\''${CAML_LD_LIBRARY_PATH:+:}${opamLib.env.packages."_".stublibs}\"" >> $out/nix-support/setup-hook
        echo "export NIX_LDFLAGS=\"\''${NIX_LDFLAGS-}\''${NIX_LDFLAGS:+ }-L${opamLib.env.packages."_".stublibs}\"" >> $out/nix-support/setup-hook
      fi
    '';

    overlayedSource = opamLib.source.fix {inherit name version src extraFiles substFiles;};

    selectedPatches =
      lib.lists.map
      ({path, ...}: "${overlayedSource}/${path}")
      (lib.filter ({filter, ...}: opamLib.filter.eval filter) patches);

    specialDuneDeps =
      if name == "dune" && lib.hasAttr "ocamlfind" ocamlPackages
      then [ocamlPackages.ocamlfind]
      else [];

    availableFrameworks =
      # Filter out the MacOS frameworks that aren't available.
      lib.mapAttrs (_: test: test.value) (
        lib.filterAttrs (_: test: test.success) (
          lib.mapAttrs (_: framework: builtins.tryEval framework) darwin.apple_sdk.frameworks
        )
      );
  in
    stdenv.mkDerivation ({
        pname = name;
        version = extraLib.cleanVersion version;

        src = overlayedSource;

        patches = selectedPatches;

        nativeBuildInputs =
          [
            git
            which
          ]
          ++ (
            if stdenv.isDarwin
            then [fixDarwinDylibNames]
            else [autoPatchelfHook]
          )
          ++
          # OPAM packages don't specify their MacOS framework dependencies. Since we
          # can't really guess, we just add all available ones.
          lib.optionals stdenv.isDarwin (lib.attrValues availableFrameworks);

        propagatedBuildInputs =
          # We want to propagate 'ocamlfind' to everything that uses 'dune'. Dune does not behave
          # correctly for us when 'ocamlfind' can't be found by it.
          specialDuneDeps
          ++ opamLib.depends.eval {inherit name;} depends
          ++ opamLib.depends.eval {
            inherit name;
            optional = true;
          }
          optionalDepends
          ++ opamLib.depends.evalNative guessedNativeDepends nativeDepends;

        checkInputs =
          opamTestLib.depends.eval {inherit name;} depends
          ++ opamTestLib.depends.eval {
            inherit name;
            optional = true;
          }
          optionalDepends
          ++ opamTestLib.depends.evalNative guessedNativeDepends nativeDepends;

        dontConfigure = true;

        buildPhase = ''
          # Build Opam package
          export OCAMLFIND_DESTDIR="$out/lib"
          export DUNE_INSTALL_PREFIX=$out
          ${renderedBuildScript}
        '';

        installPhase = ''
          # Install Opam package
          mkdir -p ${opamLib.env.local.bin} ${opamLib.env.local.lib}
          export OCAMLFIND_DESTDIR="$out/lib"
          export DUNE_INSTALL_PREFIX=$out
          ${defaultInstallScript}
          ${renderedInstallScript}
          ${lib.optionalString (name == "ocamlfind") extraOcamlfindInstallScript}
          ${fixBadInstallsScript}
          ${writeSetupHookScript}
        '';

        doCheck = with-test;

        checkPhase = ''
          # Test Opam package
          ${renderedTestScript}
        '';
      }
      // builtins.removeAttrs args [
        "name"
        "version"
        "src"
        "buildScript"
        "installScript"
        "testScript"
        "depends"
        "optionalDepends"
        "nativeDepends"
        "guessedNativeDepends"
        "extraFiles"
        "substFiles"
        "substEnv"
        "patches"
      ])
