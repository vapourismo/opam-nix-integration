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
    rev = "f4e5478242f9d70340b8d6e74a75ed035d4d544a";
    sha256 = "GvARNrqtc4R5gSJj6yWjSTr9rYuxUU4sLJLguUWiPhg=";
  };

  propagatedBuildInputs = [
    opam-state
    zeroinstall-solver
    fmt
    cmdliner
  ];
}
