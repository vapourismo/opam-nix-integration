{ lib
, runCommand
, gnumake
, ocaml
, opamvars2nix
, ocamlPackages
, opamVersion ? "2.1.2"
}:

let
  defaultOpamVars =
    import
      (
        runCommand
          "opamvars2nix"
          { buildInputs = [ opamvars2nix ]; }
          "opamvars2nix > $out"
      )
    // {
      os-distribution = "nixos";
      os-version = "1";
      opam-version = opamVersion;

      make = "${gnumake}/bin/make";

      build = true;
      post = false;
      pinned = false;
      dev = false;
    };

  defaultLocalVars = {
    prefix = "$out";
    lib = "$OCAMLFIND_DESTDIR";
    bin = "$out/bin";
    share = "$out/share";
    doc = "$out/share/doc";
    man = "$out/share/man";

    # These seem redundant.
    installed = true;
    enable = true;
  };

in

{ name
, version
, jobs ? 1
, enableTests ? false
, enableDocs ? false
, disabledPackages ? [ ]
}:

with lib;

let
  localVars =
    defaultOpamVars
    // defaultLocalVars
    // {
      inherit name version jobs;

      with-test = enableTests;
      with-doc = enableDocs;
    };

  lookupLocalVar = name:
    if lib.hasAttr name localVars then
      localVars.${name}
    else
      null;

  mkPackageVars = package: rec {
    inherit (package) name version;

    prefix = "${package}";
    lib = "${prefix}/lib/ocaml/${ocaml.version}/site-lib";
    bin = "${prefix}/bin";
    share = "${prefix}/share";
    doc = "${prefix}/share/doc";
    man = "${prefix}/share/man";

    # For 'ocaml' package
    native = true;
    native-dynlink = true;
    preinstalled = true;
  };

  packageVars = lib.mapAttrs (_: mkPackageVars) ocamlPackages;

  lookupPackageVar = packageName:
    let
      isInstalled = lib.hasAttr packageName packageVars && !(elem packageName disabledPackages);
    in

    name:

    if name == "installed" then
      isInstalled
    else if name == "enable" then
      (
        if isInstalled then
          "enable"
        else
          "disable"
      )
    else
      packageVars.${packageName}.${name} or null;

  defaultOnMissing = packageName: name:
    if packageName == null then
      abort "Unknown local variable ${name}"
    else
      abort "Unknown variable ${packageName}:${name}";

  eval = { onMissing ? defaultOnMissing }: template:
    let lookup =
      { packageName ? null
      , name
      , defaults ? { }
      }:
      let
        value =
          if packageName == null then
            lookupLocalVar name
          else
            lookupPackageVar packageName name;

        transformValue = defaults ? if_true && defaults ? otherwise;
      in
      if transformValue then
        (
          # This condition might seem strange.
          # Keep in mind that 'value' might not be a boolean.
          if value == true then
            defaults.ifTrue
          else
            defaults.otherwise
        )
      else
        (
          if value == null then
            onMissing packageName name
          else
            value
        );
    in
    template {
      local = lookup;

      package = lookup;

      toString = x:
        if builtins.isString x then
          x
        else
          builtins.toJSON x;

      combine = values:
        if lib.length values < 1 then
          abort "Attempted to combine empty list of package variable values!"
        else
          foldl' (x: y: x && y) (head values) (tail values);
    };

in

{
  inherit eval lookupLocalVar lookupPackageVar defaultOnMissing;
  local = localVars;
  packages = packageVars;
}
