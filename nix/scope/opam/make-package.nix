{ pkgs
, stdenv
, lib
, runCommand
, writeText
, writeScript
, gnumake
, unzip
, jq
, git
, which
, opamvars2nix
, opamsubst2nix
, opam-installer
}@args:

let
  callPackage = lib.callPackageWith args;

  extraLib = callPackage ../../lib { };
in

ocamlPackages:

{ name
, version
, src ? null
, buildScript ? [ ]
, installScript ? [ ]
, depends ? (_: [ ])
, optionalDepends ? (_: [ ])
, nativeDepends ? [ ]
, extraFiles ? [ ]
, substFiles ? [ ]
, ...
}@args:

let
  opamLib = extraLib.makeOpamLib { inherit name version ocamlPackages; };

  defaultInstallScript = ''
    if test -r "${name}.install"; then
      ${opam-installer}/bin/opam-installer \
        --prefix="${opamLib.env.local.prefix}" \
        --name="${name}" \
        --install "${name}.install"
    fi
  '';

  fixTopkgCommand = args:
    # XXX: A hack to deal with missing 'topfind' dependency for 'topkg'-based packages.
    if lib.lists.take 2 args == [ "ocaml" "pkg/pkg.ml" ] then
      [
        "ocaml"
        "-I"
        "${ocamlPackages.ocamlfind}/lib"
      ] ++ lib.lists.drop 1 args
    else
      args;

  fixNakedOcamlScript = args:
    # XXX: Hack to patch invocation of OCaml scripts that rely on shebang.
    if lib.lists.length args > 0 && lib.strings.hasSuffix ".ml" (lib.lists.elemAt args 0) then
      [ "${ocamlPackages.ocaml}/bin/ocaml" ] ++ args
    else
      args;

  renderedBuildScript = opamLib.commands.render (
    builtins.map
      (cmd: fixNakedOcamlScript (fixTopkgCommand cmd))
      (opamLib.commands.eval buildScript)
  );

  renderedInstallScript = opamLib.commands.render (opamLib.commands.eval installScript);

  overlayedSource = opamLib.source.fix { inherit name version src extraFiles substFiles; };

in
stdenv.mkDerivation ({
  pname = name;
  version = extraLib.cleanVersion version;

  src = overlayedSource;

  buildInputs = [ git which ];

  propagatedBuildInputs =
    (with ocamlPackages; [ ocaml ocamlfind ])
      ++ opamLib.depends.eval { inherit name; } depends
      ++ opamLib.depends.eval { inherit name; optional = true; } optionalDepends;

  propagatedNativeBuildInputs = opamLib.depends.evalNative nativeDepends;

  dontConfigure = true;

  buildPhase = ''
    # Build Opam package
    ${renderedBuildScript}
  '';

  installPhase = ''
    # Install Opam package
    mkdir -p ${opamLib.env.local.bin} ${opamLib.env.local.lib}
    ${defaultInstallScript}
    ${renderedInstallScript}
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
  "substFiles"
])
