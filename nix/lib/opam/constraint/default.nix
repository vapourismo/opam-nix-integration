{ filterLib, cleanVersion }:

{
  eval = import ./eval.nix { inherit filterLib cleanVersion; };
  show = import ./show.nix { inherit filterLib; };
}
