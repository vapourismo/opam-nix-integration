{...}: let
  overrideOpamDrv = drv: newArgs:
    drv.override (prev: {
      mkOpamDerivation = args: prev.mkOpamDerivation (args // newArgs);
    });

  overrideNativeDepends = drv: nativePackages:
    overrideOpamDrv drv {
      # Disable any guessed native dependencies.
      guessedNativeDepends = [];

      # Override the list of native dependencies.
      nativeDepends = [
        {
          filter = {bool, ...}: bool true;
          inherit nativePackages;
        }
      ];
    };
in {
  inherit overrideOpamDrv overrideNativeDepends;
}
