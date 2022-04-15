{ filterLib, ... }@depends:

{
  eval = import ./eval.nix depends;
  show = import ./show.nix { inherit filterLib; };
}
