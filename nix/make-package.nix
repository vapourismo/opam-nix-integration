{ lib, stdenv, ocaml, findlib }:

let
  solveDependsLib = {
    __formulaScope = {
      and = left: right: if left != null && right != null then left ++ right else null;

      empty = [ ];

      or = left: right: if left != null then left else right;
    };

    __packageWhen = package: versionCheck:
      let
        eligible =
          if builtins.isFunction versionCheck then
            versionCheck package.version
          else if builtins.isBool versionCheck then
            versionCheck
          else
            versionCheck != null;
      in
      if eligible then [ package ] else null;

    __constraintScope = {
      equal = version: package: builtins.compareVersions package version == 0;
      notEqual = version: package: builtins.compareVersions package version != 0;
      greaterEqual = version: package: builtins.compareVersions package version  >= 0;
      greaterThan = version: package: builtins.compareVersions package version > 0;
      lowerEqual = version: package: builtins.compareVersions package version <= 0;
      lowerThan = version: package: builtins.compareVersions package version < 0;
    };
  };

in
{ name
, version
, src ? null
, buildScript ? ""
, installScript ? ""
, solveDepends ? (_: [ ])
, nativeDepends ? [ ]
, extraFiles ? [ ]
, ...
}@args:

stdenv.mkDerivation ({
  pname = name;
  inherit version;

  inherit src;
  dontUnpack = src == null;

  buildInputs = [ ocaml findlib ];

  propagatedBuildInputs = solveDepends solveDependsLib;
  propagatedNativeBuildInputs = nativeDepends;

  patchPhase = builtins.concatStringsSep "\n" (
    builtins.map (file: "cp ${file.source} ${file.path}") extraFiles
  );

  configurePhase = ''
    # Configure Opam package
  '';

  buildPhase = ''
    # Build Opam package
    ${buildScript}
  '';

  installPhase = ''
    # Install Opam package
    mkdir -p $out/lib
    ${installScript}
  '';
} // builtins.removeAttrs args [
  "name"
  "version"
  "src"
  "buildScript"
  "installScript"
  "solveDepends"
  "nativeDepends"
  "extraFiles"
])
