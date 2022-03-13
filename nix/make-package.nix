{ pkgs
, runCommand
, lib
, stdenv
, ocamlPackages
, ocaml
, findlib
, gnumake
, opamvars2nix
, opam-installer
}:

let
  opam = import ./opam.nix;

in
{ name
, version
, src ? null
, buildScript ? [ ]
, installScript ? [ ]
, depends ? (_: [ ])
, optionalDepends ? (_: [ ])
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

  defaultInstallScript = ''
    if test -r "${name}.install"; then
      ${opam-installer}/bin/opam-installer \
        --prefix="${env.local.prefix}" \
        --libdir="${env.local.lib}" \
        --docdir="${env.local.doc}" \
        --mandir="${env.local.man}" \
        --name="${name}" \
        --install "${name}.install"
    fi
  '';

  renderedInstallScript = opam.evalCommands env installScript;

  finalInstallScript =
    if renderedInstallScript == "" then
      defaultInstallScript
    else
      renderedInstallScript;

in
stdenv.mkDerivation ({
  pname = name;
  version = opam.cleanVersion version;

  inherit src;
  dontUnpack = src == null;

  buildInputs = [ ocaml findlib ];

  propagatedBuildInputs =
    opam.evalDependenciesFormula name env ocamlPackages depends
      ++ opam.evalDependenciesFormula name env ocamlPackages optionalDepends;

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
    ${finalInstallScript}
  '';
} // builtins.removeAttrs args [
  "name"
  "version"
  "src"
  "buildScript"
  "installScript"
  "depends"
  "optionalDepends"
  "nativeDepends"
  "extraFiles"
])
