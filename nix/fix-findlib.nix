{ writeText, findlib }:

findlib.overrideAttrs (old: {
  # This should only differ from the upstream findlib in the '-sitelib' flag which has been adjusted
  # to match the behavior of Opam.
  configureFlags = [
    "-bindir"
    "${placeholder "out"}/bin"
    "-mandir"
    "${placeholder "out"}/share/man"
    "-sitelib"
    "${placeholder "out"}/lib"
    "-config"
    "${placeholder "out"}/etc/findlib.conf"
  ];

  # The '/lib' and '/lib/stublibs' paths have been updated below to match Opam behavior.
  setupHook = writeText "setupHook.sh" ''
    addOCamlPath () {
        if test -d "''$1/lib"; then
            export OCAMLPATH="''${OCAMLPATH-}''${OCAMLPATH:+:}''$1/lib"
        fi

        if test -d "''$1/lib/stublibs"; then
            export CAML_LD_LIBRARY_PATH="''${CAML_LD_LIBRARY_PATH-}''${CAML_LD_LIBRARY_PATH:+:}''$1/lib/stublibs"
        fi
    }

    exportOcamlDestDir () {
        export OCAMLFIND_DESTDIR="''$out/lib"
    }

    createOcamlDestDir () {
        if test -n "''${createFindlibDestdir-}"; then
          mkdir -p $OCAMLFIND_DESTDIR
        fi
    }

    # run for every buildInput
    addEnvHooks "$targetOffset" addOCamlPath

    # run before installPhase, even without buildInputs, and not in nix-shell
    preInstallHooks+=(createOcamlDestDir)

    # run even in nix-shell, and even without buildInputs
    addEnvHooks "$hostOffset" exportOcamlDestDir
  '';
})
