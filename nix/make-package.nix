{ stdenv, ocaml, findlib }:

{ name
, version
, src ? null
, buildScript ? ""
, installScript ? ""
, depends ? [ ]
, nativeDepends ? [ ]
, extraFiles ? [ ]
}:

stdenv.mkDerivation {
  pname = name;
  inherit version;

  inherit src;
  dontUnpack = src == null;

  buildInputs = [ ocaml findlib ];

  propagatedBuildInputs = depends;
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
}
