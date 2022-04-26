{ lib, envLib, filterLib }:

let
  shouldKeep = { filter, ... }: filterLib.eval filter;

  pruneArg = { arg, ... }: envLib.eval { } arg;

  pruneCommand = { args, ... }: lib.lists.map pruneArg (lib.filter shouldKeep args);

  eval = cmds: lib.lists.map pruneCommand (lib.filter shouldKeep cmds);

  renderArg = arg: ''"${lib.strings.escape [ "\"" ] arg}"'';

  render = cmds: lib.concatStringsSep "\n" (
    lib.lists.map (args: lib.concatStringsSep " " (lib.lists.map renderArg args)) cmds
  );
in

{
  inherit eval render;
}
