{lib, ...}: let
  mkJobSet = prefix: {
    enabled = 1;
    hidden = false;
    description = "Packages starting with ${prefix}";
    nixexprinput = "opam-nix-integration";
    nixexprpath = "hydra/jobs.nix";
    checkinterval = 86400;
    schedulingshares = 1;
    enableemail = false;
    emailoverride = "";
    keepnr = 3;
    inputs = {
      prefix = {
        type = "string";
        value = prefix;
        emailresponsible = false;
      };

      opam-repository = {
        type = "git";
        value = "https://github.com/ocaml/opam-repository";
        emailresponsible = false;
      };

      nixpkgs = {
        type = "git";
        value = "https://github.com/NixOS/nixpkgs";
        emailresponsible = false;
      };

      opam-nix-integration = {
        type = "git";
        value = "https://github.com/vapourismo/opam-nix-integration";
        emailresponsible = false;
      };
    };
  };
in
  lib.genAttrs [
    "a"
    "b"
    "c"
    "d"
    "e"
    "f"
    "g"
    "h"
    "i"
    "j"
    "k"
    "l"
    "m"
    "n"
    "o"
    "p"
    "q"
    "r"
    "s"
    "t"
    "u"
    "v"
    "w"
    "x"
    "y"
    "z"
  ]
  mkJobSet
