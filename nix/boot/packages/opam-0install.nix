{
  buildDunePackage,
  fetchFromGitHub,
  opam-state,
  zeroinstall-solver,
  fmt,
  cmdliner,
}:
buildDunePackage {
  pname = "opam-0install";
  version = "0.4.2";

  duneVersion = "3";

  src = fetchFromGitHub {
    owner = "ocaml-opam";
    repo = "opam-0install-solver";
    rev = "f48784c0cf9625d9ed9aa95d7a61f495e619bd93";
    sha256 = "sha256-Gf9m7xAP9G9Db1sWyGuWQgoJQjASVr4NrsjBwFBWibQ=";
  };

  propagatedBuildInputs = [
    opam-state
    zeroinstall-solver
    fmt
    cmdliner
  ];
}
