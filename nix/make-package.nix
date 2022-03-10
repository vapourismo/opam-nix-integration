{ lib, stdenv, ocamlPackages, ocaml, findlib }:

let
  opam = import ./opam.nix;

in
{ name
, version
, src ? null
, buildScript ? ""
, installScript ? ""
, depends ? (_: [ ])
, nativeDepends ? [ ]
, extraFiles ? [ ]
, ...
}@args:

let
  env = {
    local = {
      inherit version;
    };

    packages = { };
  };

in
stdenv.mkDerivation ({
  pname = name;
  inherit version;

  inherit src;
  dontUnpack = src == null;

  buildInputs = [ ocaml findlib ];

  propagatedBuildInputs = opam.evalDependenciesFormula env ocamlPackages depends;

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
  "depends"
  "nativeDepends"
  "extraFiles"
])
