{ pkgs, lib, stdenv, ocamlPackages, ocaml, findlib, gnumake }:

let
  opam = import ./opam.nix;

in
{ name
, version
, src ? null
, buildScript ? [ ]
, installScript ? [ ]
, depends ? (_: [ ])
, nativeDepends ? [ ]
, extraFiles ? [ ]
, ...
}@args:

let
  env = {
    local = {
      inherit name version;
      jobs = 1;
      dev = false;
      with-test = false;
      with-doc = false;
      build = true;
      make = "${gnumake}/bin/make";

      os = "linux";
      arch = "x86_64";
      os-distribution = "nixos";
      os-family = "nixos";
      prefix = "$out";
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

  propagatedNativeBuildInputs = opam.evalNativeDependencies env pkgs nativeDepends;

  patchPhase = builtins.concatStringsSep "\n" (
    builtins.map (file: "cp ${file.source} ${file.path}") extraFiles
  );

  configurePhase = ''
    # Configure Opam package
  '';

  buildPhase = ''
    # Build Opam package
    ${opam.evalCommands env buildScript}
  '';

  installPhase = ''
    # Install Opam package
    mkdir -p $out/lib
    ${opam.evalCommands env installScript}
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
