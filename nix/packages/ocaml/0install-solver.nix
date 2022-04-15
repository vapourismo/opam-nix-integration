{ buildDunePackage, fetchFromGitHub }:

buildDunePackage {
  pname = "0install-solver";
  version = "2.17";

  useDune2 = true;

  src = fetchFromGitHub {
    owner = "0install";
    repo = "0install";
    rev = "4a837bd638d93905b96d073c28c644894f8d4a0b";
    sha256 = "sha256-OsHJNh99oEQxCUH4GuV1sAlUhxCIxcW3oodgojgRskw=";
  };
}
