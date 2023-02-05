{
  lib,
  stdenv,
  writeScript,
  cleanVersion,
  substLib,
  jq,
  unzip,
}: let
  mkCopyExtraFilesScript = extraFiles:
    lib.concatStringsSep "\n" (
      lib.lists.map ({
        src,
        path,
      }: "cp ${src} $out/${path}")
      extraFiles
    );

  fixCargoChecksumsScript = writeScript "fix-cargo-checksum" ''
    jq "{ package: .package, files: { } }" "$1" > "$1.empty"
    mv "$1.empty" "$1"
  '';

  overlayExtraFiles = {
    name,
    version,
    src,
    extraFiles,
    ...
  }:
    stdenv.mkDerivation {
      name = "opam2nix-${name}-${cleanVersion version}-source-phase1";

      inherit src;
      dontUnpack = src == null;

      unpackCmd = "tar xf $curSrc";

      setSourceRoot = ''
        export sourceRoot="$(find . -type d -mindepth 1 -maxdepth 1 ! -name env-vars)"

        # If the unpack command creates multiple directories we'll choose the most top-level directory
        # as our source root.
        if [[ $(echo "$sourceRoot" | wc -l) -gt 1 ]]; then
          export sourceRoot="."
        fi
      '';

      buildInputs = [unzip];

      phases = ["unpackPhase" "installPhase"];

      installPhase = ''
        mkdir -p $out
        cp -r . $out

        # Resolve extra files
        ${mkCopyExtraFilesScript extraFiles}
      '';
    };

  writeSubsts = {
    src,
    substFiles,
  }:
    lib.concatStringsSep "\n" (
      lib.lists.map
      (file: "cp -v ${substLib.rewrite "${src}/${file}.in"} $out/${file}")
      substFiles
    );

  fixSource = {
    name,
    version,
    substFiles,
    ...
  } @ args: let
    src = overlayExtraFiles args;
  in
    stdenv.mkDerivation {
      name = "opam2nix-${name}-${cleanVersion version}-source";

      inherit src;

      buildInputs = [jq];

      phases = ["unpackPhase" "installPhase"];

      installPhase = ''
        mkdir -p $out
        cp -r . $out

        # Write substitutions
        ${writeSubsts {inherit src substFiles;}}

        # Patch shebangs in shell scripts
        patchShebangsAuto

        # Fix Cargo checksum files
        find $out -name .cargo-checksum.json -exec ${fixCargoChecksumsScript} {} \;
      '';
    };
in {
  fix = fixSource;
}
