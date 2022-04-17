{ system, writeText, findlib }:

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

  # The Nix-native 'findlib' has a setup hook. Unfortunately that hook only triggers when
  # packages actually have a dependency this package. Lots of OPAM packages do not specify this
  # dependency explicitly and would therefore miss out on this setup hook. In order for all packages
  # to have access to it, this hook is separately injected in the build phase of each package.
  setupHook = writeText "setupHook.sh" ''
    # Nothing
  '';

  meta = old.meta // {
    # ocamlfind gets the list of platforms from the 'ocaml' package but defaults to the empty list
    # if not set. When using 'opam2nix' to compile the 'ocaml' package, 'meta.platforms' is not set.
    platforms = [ system ];
  };
})
