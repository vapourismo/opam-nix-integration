{
  writeText,
  runCommand,
  opamsubst2nix,
  envLib,
}: let
  rewrite = src:
    writeText "opam2nix-subst-file" (
      envLib.interpolate (
        import (
          runCommand
          "opam2nix-subst-expr"
          {
            inherit src;
            buildInputs = [opamsubst2nix];
          }
          "opamsubst2nix < $src > $out"
        )
      )
    );
in {
  inherit rewrite;
}
