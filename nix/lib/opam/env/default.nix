{
  lib,
  runCommand,
  gnumake,
  opam2nix,
  opamVersion ? "2.1.2",
}: let
  defaultOpamVars =
    import
    (
      runCommand
      "opam2nix-vars"
      {buildInputs = [opam2nix];}
      "opam2nix opam-variables > $out"
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
  {
    name,
    version,
    jobs ? 1,
    with-test ? false,
    with-doc ? false,
    with-dev-setup ? false,
    ocamlPackages,
    disabledPackages ? [],
  }:
    with lib; let
      localVars =
        defaultOpamVars
        // defaultLocalVars
        // rec {
          inherit name version jobs with-test with-doc with-dev-setup;

          prefix = "$out";
          lib = "${prefix}/lib";
          libexec = "${prefix}/lib";
          stublibs = "${prefix}/lib/stublibs";
          bin = "${prefix}/bin";
          sbin = "${prefix}/bin";
          share = "${prefix}/share";
          doc = "${prefix}/share/doc";
          man = "${prefix}/share/man";
          etc = "${prefix}/etc";
        };

      lookupLocalVar = name:
        if lib.hasAttr name localVars
        then localVars.${name}
        else null;

      mkPackageVars = package: rec {
        inherit (package) version;
        name = package.pname;

        prefix = "${package}";
        lib = "${prefix}/lib/${name}";
        lib_root = "${prefix}/lib";
        libexec = lib;
        libexec_root = lib_root;
        stublibs = "${prefix}/lib/stublibs";
        bin = "${prefix}/bin";
        sbin = "${prefix}/bin";
        share = "${prefix}/share/${name}";
        share_root = "${prefix}/share";
        doc = "${prefix}/share/doc/${name}";
        man = "${prefix}/share/man";
        etc = "${prefix}/etc/${name}";

        # For 'ocaml' package
        native = true;
        native-dynlink = true;
        preinstalled = true;
      };

      packageVars =
        lib.mapAttrs (_: mkPackageVars) ocamlPackages
        // {
          _ = rec {
            inherit name version;

            prefix = "$out";
            lib = "${prefix}/lib/${name}";
            lib_root = "${prefix}/lib";
            libexec = lib;
            libexec_root = lib_root;
            stublibs = "${prefix}/lib/stublibs";
            bin = "${prefix}/bin";
            sbin = "${prefix}/bin";
            share = "${prefix}/share/${name}";
            share_root = "${prefix}/share";
            doc = "${prefix}/share/doc";
            man = "${prefix}/share/man";
            etc = "${prefix}/etc/${name}";
          };
        };

      lookupPackageVar = packageName: let
        isInstalled = lib.hasAttr packageName packageVars && !(elem packageName disabledPackages);
      in
        name:
          if name == "installed"
          then isInstalled
          else if name == "enable"
          then
            (
              if isInstalled
              then "enable"
              else "disable"
            )
          else packageVars.${packageName}.${name} or null;

      defaultOnMissing = packageName: name:
        if packageName == null
        then abort "Unknown local variable ${name}"
        else abort "Unknown variable ${packageName}:${name}";

      eval = {onMissing ? defaultOnMissing}: template: let
        lookup = {
          packageName ? null,
          name,
          defaults ? {},
        }: let
          value =
            if packageName == null
            then lookupLocalVar name
            else lookupPackageVar packageName name;

          transformValue = defaults ? ifTrue && defaults ? otherwise;
        in
          if transformValue
          then
            (
              # This condition might seem strange.
              # Keep in mind that 'value' might not be a boolean.
              if value == true
              then defaults.ifTrue
              else defaults.otherwise
            )
          else
            (
              if value == null
              then onMissing packageName name
              else value
            );
      in
        template {
          inherit lookup;

          toString = x:
            if lib.isString x
            then x
            else builtins.toJSON x;

          combine = values:
            if lib.length values < 1
            then abort "Attempted to combine empty list of package variable values!"
            else foldl' (x: y: x && y) (head values) (tail values);
        };

      interpolate = eval {onMissing = _: _: null;};
    in {
      inherit eval interpolate lookupLocalVar lookupPackageVar defaultOnMissing;
      local = localVars;
      packages = packageVars;
    }
