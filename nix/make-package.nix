{ pkgs, runCommand, lib, stdenv, ocamlPackages, ocaml, findlib, gnumake, opamvars2nix }:

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
  defaultVariables = import (
    runCommand
      "opamvars2nix"
      {
        buildInputs = [ opamvars2nix ];
      }
      "opamvars2nix > $out"
  );

  env = {
    local = defaultVariables // {
      inherit name version;
      jobs = 1;

      dev = false;
      with-test = false;
      with-doc = false;
      build = true;
      post = false;
      pinned = false;

      os-distribution = "nixos";

      make = "${gnumake}/bin/make";

      prefix = "$out";
      lib = "$OCAMLFIND_DESTDIR";
      bin = "$out/bin";
      share = "$out/share";
      doc = "$out/share/doc";
      man = "$out/share/man";
    };

    packages = package: {
      installed = builtins.hasAttr package ocamlPackages;
      enable = builtins.hasAttr package ocamlPackages;

      # For 'ocaml' package
      native = true;
      native-dynlink = true;
      preinstalled = true;
    };
  };

in
stdenv.mkDerivation ({
  pname = name;
  version = opam.cleanVersion version;

  inherit src;
  dontUnpack = src == null;

  buildInputs = [ ocaml findlib ];

  propagatedBuildInputs = opam.evalDependenciesFormula name env ocamlPackages depends;

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
