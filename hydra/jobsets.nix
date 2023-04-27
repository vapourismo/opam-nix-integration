{
  lib,
  opam-nix-integration,
  ...
}: let
  mkJobSet = name: {
    enabled = 1;
    hidden = false;
    description = name;
    nixexprinput = "opam-nix-integration";
    nixexprpath = "hydra/jobs.nix";
    checkinterval = 86400;
    schedulingshares = 1;
    enableemail = false;
    emailoverride = "";
    keepnr = 3;
    inputs = {
      name = {
        type = "string";
        value = name;
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
        value = "https://github.com/vapourismo/opam-nix-integration feature/individual-hydra-jobs";
        emailresponsible = false;
      };
    };
  };
in
  lib.genAttrs (lib.attrNames opam-nix-integration.repository.packages) mkJobSet
