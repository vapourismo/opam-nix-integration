# opam-nix-integration

This project aims to provide an integration mechanism for OPAM packages into Nix.

To achieve this, it supplies two key solutions for common use cases:

  * Build a package set from a list of constraints and an [opam-repository][opam-repository].
  * Produce a Nix derivation from an OPAM file.

## Getting started

The following sets up a package set using a version of [opam-repository][opam-repository] and some constraints we have against those packages. After that it produces a derivation for the OPAM package in the current directory.

```nix
let
  # Fetch the Opam Nix integration library.
  opam-nix-integration =
    import
      (fetchTarball "https://github.com/vapourismo/opam-nix-integration/archive/master.tar.gz");

  # Fetch Nixpkgs and inject our overlay.
  pkgs =
    import
      (fetchTarball "https://github.com/NixOS/nixpkgs/archive/master.tar.gz")
      { overlays = [ opam-nix-integration.overlay ]; };

  # Fetch the opam-repository.
  opam-repository = pkgs.fetchFromGitHub {
    owner = "ocaml";
    repo = "opam-repository";
    rev = "5269af290fff3fc631a8855e4255b4b53713b467";
    sha256 = "sha256-6sFe1838OthFRUhJQ74u/k0urk7Om/gSNnX67BE+DJs=";
  };

  # Create a package set using some constraints against the packages available in opam-repository.
  packageSet = pkgs.opamPackages.overrideScope' (pkgs.lib.composeManyExtensions [
    # Set the opam-repository which has all our package descriptions.
    (final: prev: {
      repository = prev.repository.override { src = opam-repository; };
    })

    # Specify the constraints we have.
    (final: prev: prev.repository.select {
      packageConstraints = [
        "ocaml = 4.14.1"
        "dune >= 3.4"
        "zarith"
        "opam-format"
        "opam-state"
        "opam-0install"
        "cmdliner"
        "ppx_deriving"
      ];
    })
  ]);
in

# Generate a Nix derivation using a OPAM package in the current directory.
packageSet.callOpam2Nix {
  name = "nix";
  version = "0.0.0";
  src = ./.;
} {}
```

## Package set functionality

### `callOpam2Nix`

`callOpam2Nix` takes 2 attribute set parameters and generates a derivation. The first configures the generation of the Nix derivation from the OPAM file. Whereas the second is passed directly to the derivation in a similar way to `callPackage`.

Example:

```nix
packageSet.callOpam2Nix
  {
    name = "my_package";
    version = "1.2.3";
    src = /source/of/my_package;
  }
  {
    jobs = 16;
    with-test = true;
  }
```

Options for the first parameter:

| Name | Type | Required? | Description |
|------|------|-----------|-------------|
| `name` | `string` | Yes | OPAM package name |
| `version` | `string` | Yes | Package version |
| `opam` | `path` | No | Path to the OPAM file to processed. This will default to `${src}/${name}.opam` if you omit it. That means you have to provide `src` when skipping `opam`. |
| `src` | `path` | No | You can specify this parameter if you'd like to override the source for the package. If you skip it, the source specified in the OPAM file will be used. |
| `patches` | `list` of `path`s | No | These patches will be applied to the OPAM file ahead of processing. |
| `extraFiles` | `path` | No | Some packages need extra files via the `extra-files` stanza. Those files will be looked up in `extraFiles`. |

These are some of the options for the second parameter:

| Name | Type | Description |
|------|------|-------------|
| `jobs` | `int` | Sets the `jobs` OPAM variable for that package. This can be used to scale the build parallelism. |
| `with-test` | `bool` | Sets the `with-test` OPAM variable for that package. Usually that enables building and running tests. |
| `with-doc` | `bool` | Sets the `with-doc` OPAM variable for that package. In most cases documentation will be built and installed if set to `true`. |

### `callOpam`

`callOpam` is almost identical to `callOpam2Nix` except that it finds the right values for `opam` and `extraFiles` parameters specific to the configured OPAM repository for you.

Example:

```nix
let
  packageSet = ...;

  dune_2 = packageSet.callOpam {
    name = "dune";
    version = "2.9.3";
  } {};
in
...
```

### `repository.packages.${name}.${version}`

This is a shortcut for calling `callOpam { inherit name version; } {}`.

Example:

```nix
let
  packageSet = ...;

  dune_2 = packageSet.repository.packages.dune."2.9.3";
in
...
```

### `repository.packages.${name}.latest`

Like `repository.packages.${name}.${version}` but for the latest version of that package.

Example:

```nix
let
  packageSet = ...;

  latest_dune = packageSet.repository.packages.dune.latest;
in
...
```

### `repository.select`

This function allows you to select an attribute set of packages given some constraints.

| Parameter | Type | Description |
|-----------|------|-------------|
| `packageConstraints` | `list` of `string`s | Here you can specify which packages you'd like to have in the package set including an optional version constraint. A constraint is imposed if you add a relation operator and version after the package name like so: `package = 1.2.3`. |
| `testablePackages` | `list` of `string`s | These are the names of packages whose test dependencies should be included in the package set. |
| `opams` | `list` of `attrset` | This list of pinned `.opam` package descriptions will be included in the resolution of the package set. |

Example:

```nix
let
  packageSet = ...;
in
packageSet.overrideScope' (final: prev: prev.repository.select {
  packageConstraints = ["dune >= 3.2"];
  opams = [
    { name = "my-package"; opam = ./my-package.opam; }
  ];
})
```

## Known problems

### Dune 3.0 and 3.1 direct installation mode

As reported in [ocaml/dune#5455][dune-install-issue], Dune 3+ wants either an explicit `--prefix` command-line argument or the `opam` executable in scope when installing build results directly. We can't do either at the moment unfortunately.

Luckily, this installation method is not super common - most Dune-based projects generate `.install` files instead which work fine.

A [workaround][dune-install-fix] has been accepted in Dune that will be available from version 3.2 onwards.

[opam-repository]: https://github.com/ocaml/opam-repository
[dune-install-issue]: https://github.com/ocaml/dune/issues/5455
[dune-install-fix]: https://github.com/ocaml/dune/pull/5589
