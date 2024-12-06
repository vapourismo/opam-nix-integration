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
    rev = "b58af5db6afd496cfd4a5f85fb23f30ba8dfbc87";
    sha256 = "CxADWMYZBPobs65jeyMQjqu3zmm2PgtNgI/jUsYUp8I=";
  };
}
