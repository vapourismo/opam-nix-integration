{ lib, envLib, filterLib }:

let
  shouldKeep = { filter, ... }: filterLib.eval filter;

  pruneArg = { arg, ... }: envLib.eval { } arg;

  pruneCommand = { args, ... }: builtins.map pruneArg (builtins.filter shouldKeep args);

  eval = cmds: builtins.map pruneCommand (builtins.filter shouldKeep cmds);

  render = cmds: builtins.concatStringsSep "\n" (
    builtins.map (args: builtins.concatStringsSep " " (builtins.map builtins.toJSON args)) cmds
  );
in

{
  inherit eval render;
}
