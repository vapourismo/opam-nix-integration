{ buildDunePackage
, fetchFromGitHub
, opam-state
, zeroinstall-solver
, fmt
, cmdliner
}:

buildDunePackage {
  pname = "opam-0install";
  version = "0.4.2";

  duneVersion = "3";

  src = fetchFromGitHub {
    owner = "ocaml-opam";
    repo = "opam-0install-solver";
    rev = "eb08da5434a8c8227af39927b99b5cc15e82c053";
    sha256 = "sha256-+AD5zSAKZ4k2G+RsrKq1MxzjuGV4qdfOpt4TJxDMlEk=";
  };

  propagatedBuildInputs = [
    opam-state
    zeroinstall-solver
    fmt
    cmdliner
  ];
}
