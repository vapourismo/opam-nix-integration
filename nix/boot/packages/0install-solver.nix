{
  buildDunePackage,
  fetchFromGitHub,
}:
buildDunePackage {
  pname = "0install-solver";
  version = "2.17";

  duneVersion = "3";

  src = fetchFromGitHub {
    owner = "0install";
    repo = "0install";
    rev = "225587eef889a3082e0cc53fa64500f56cca0028";
    sha256 = "sha256-+d+2p5vJaVWTVroDvaDqzhcSlccTTt7ntWZ+TK8meuk=";
  };
}
