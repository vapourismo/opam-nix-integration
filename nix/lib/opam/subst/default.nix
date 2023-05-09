{
  writeText,
  runCommand,
  opam2nix,
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
            buildInputs = [opam2nix];
          }
          "opam2nix substitute < $src > $out"
        )
      )
    );
in {
  inherit rewrite;
}
