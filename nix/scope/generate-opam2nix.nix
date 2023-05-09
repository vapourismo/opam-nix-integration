{
  lib,
  runCommand,
  opam2nix,
}: {
  name,
  version,
  opam,
  patches ? [],
  extraFiles ? null,
}:
import (
  runCommand
  "opam2nix-${name}-${version}"
  {
    buildInputs = [opam2nix];
    inherit opam patches;
  }
  ''
    cp $opam opam
    chmod +w opam
    for patch in $patches; do
      patch opam $patch
    done
    opam2nix generate-derivation \
      --name ${name} \
      --version ${version} \
      ${lib.optionalString (extraFiles != null && lib.pathExists extraFiles) "--extra-files ${extraFiles}"} \
      --file opam > $out
  ''
)
