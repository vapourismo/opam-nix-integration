pkgs: final: prev:

let
  selectLatest = packages: builtins.listToAttrs (
    builtins.map
      (name: {
        inherit name;
        value = final.opamPackages.${name}.latest;
      })
      packages
  );
in

{
  dune = pkgs.ocaml-ng.ocamlPackages_4_13.dune_2;
  inherit (pkgs.ocaml-ng.ocamlPackages_4_13) ocamlbuild ocaml-freestanding;

  dune-configurator = final.opamPackages.dune-configurator.${final.dune.version};
  ocaml-src = final.opamPackages.ocaml-src.${final.ocaml.version};
  camlp4 = final.opamPackages.camlp4."4.13+1";

  conf-gmp =
    final.callOpam
      {
        name = "conf-gmp";
        version = "4";
        patches = [ ../patches/conf-gmp-4.patch ];
      }
      { };

  conf-libffi =
    final.callOpam
      {
        name = "conf-libffi";
        version = "2.0.0";
        patches = [ ../patches/conf-libffi-2.0.0.patch ];
      }
      { };

  zarith =
    final.callOpam
      {
        name = "zarith";
        version = "1.12";
        patches = [ ../patches/zarith-1.12.patch ];
      }
      { };

  cmdliner =
    final.callOpam
      {
        name = "cmdliner";
        version = "1.0.4";
        patches = [ ../patches/cmdliner-1.0.4.patch ];
      }
      { };

  checkseum =
    final.callOpam
      {
        name = "checkseum";
        version = "0.3.2";
        patches = [ ../patches/checkseum-0.3.2.patch ];
      }
      { };

  ppxlib = final.opamPackages.ppxlib."0.24.0";

  # These packages have messed up versions published.
  ppx_sexp_conv = final.opamPackages.ppx_sexp_conv."v0.14.3";
  sexplib = final.opamPackages.sexplib."v0.14.0";
  core = final.opamPackages.core."v0.14.1";
  core_kernel = final.opamPackages.core_kernel."v0.14.2";
  ppx_jane = final.opamPackages.ppx_jane."v0.14.0";
  bin_prot = final.opamPackages.bin_prot."v0.14.0";
  fieldslib = final.opamPackages.fieldslib."v0.14.0";
  jane-street-headers = final.opamPackages.jane-street-headers."v0.14.0";
  ppx_assert = final.opamPackages.ppx_assert."v0.14.0";
  ppx_base = final.opamPackages.ppx_base."v0.14.0";
  ppx_hash = final.opamPackages.ppx_hash."v0.14.0";
  ppx_inline_test = final.opamPackages.ppx_inline_test."v0.14.1";
  ppx_sexp_message = final.opamPackages.ppx_sexp_message."v0.14.1";
  splittable_random = final.opamPackages.splittable_random."v0.14.0";
  typerep = final.opamPackages.typerep."v0.14.0";
  variantslib = final.opamPackages.variantslib."v0.14.0";
  ppx_optcomp = final.opamPackages.ppx_optcomp."v0.14.3";
  ppx_bench = final.opamPackages.ppx_bench."v0.14.1";
  ppx_bin_prot = final.opamPackages.ppx_bin_prot."v0.14.0";
  ppx_custom_printf = final.opamPackages.ppx_custom_printf."v0.14.1";
  ppx_expect = final.opamPackages.ppx_expect."v0.14.2";
  ppx_fields_conv = final.opamPackages.ppx_fields_conv."v0.14.2";
  ppx_here = final.opamPackages.ppx_here."v0.14.0";
  ppx_let = final.opamPackages.ppx_let."v0.14.0";
  ppx_module_timer = final.opamPackages.ppx_module_timer."v0.14.0";
  ppx_optional = final.opamPackages.ppx_optional."v0.14.0";
  ppx_pipebang = final.opamPackages.ppx_pipebang."v0.14.0";
  ppx_sexp_value = final.opamPackages.ppx_sexp_value."v0.14.0";
  ppx_stable = final.opamPackages.ppx_stable."v0.14.1";
  ppx_typerep_conv = final.opamPackages.ppx_typerep_conv."v0.14.2";
  ppx_string = final.opamPackages.ppx_string."v0.14.1";
  ppx_variants_conv = final.opamPackages.ppx_variants_conv."v0.14.2";
  ppx_cold = final.opamPackages.ppx_cold."v0.14.0";
  ppx_compare = final.opamPackages.ppx_compare."v0.14.0";
  ppx_enumerate = final.opamPackages.ppx_enumerate."v0.14.0";
  ppx_js_style = final.opamPackages.ppx_js_style."v0.14.1";
  ppx_fixed_literal = final.opamPackages.ppx_fixed_literal."v0.14.0";
} // selectLatest [
  "bigarray-compat"
  "bigstringaf"
  "alcotest-lwt"
  "alcotest"
  "astring"
  "awa-mirage"
  "awa"
  "base-bytes"
  "base-threads"
  "base-unix"
  "base64"
  "bheap"
  "bisect_ppx"
  "bos"
  "ca-certs-nss"
  "ca-certs"
  "cf-lwt"
  "cohttp-lwt-unix"
  "cohttp-lwt"
  "cohttp"
  "conduit-lwt-unix"
  "conduit-lwt"
  "conduit"
  "conf-perl"
  "conf-pkg-config"
  "cppo"
  "csexp"
  "cstruct"
  "ctypes"
  "decompress"
  "digestif"
  "dns-client"
  "domain-name"
  "duration"
  "eqaf"
  "ezjsonm"
  "fpath"
  "fsevents-lwt"
  "git-mirage"
  "git-unix"
  "git"
  "graphql_parser"
  "graphql-cohttp"
  "graphql-lwt"
  "graphql"
  "happy-eyeballs-lwt"
  "happy-eyeballs"
  "hex"
  "index"
  "inotify"
  "ipaddr-sexp"
  "ipaddr"
  "irmin-fs"
  "irmin-git"
  "irmin-graphql"
  "irmin-http"
  "irmin-mem"
  "irmin-pack"
  "irmin-test"
  "irmin-tezos"
  "irmin-unix"
  "irmin-watcher"
  "irmin"
  "jsonm"
  "junit_alcotest"
  "ke"
  "logs"
  "lwt_log"
  "lwt_ssl"
  "lwt-unix"
  "lwt"
  "magic-mime"
  "mdx"
  "metrics-unix"
  "metrics"
  "mirage-clock-unix"
  "mirage-clock"
  "mirage-crypto-rng"
  "mirage-flow"
  "mirage-mmap"
  "mirage-time"
  "mirage-unix"
  "mmap"
  "mtime"
  "ocaml-syntax-shims"
  "ocaml-version"
  "ocamlgraph"
  "ocplib-endian"
  "odoc-parser"
  "odoc"
  "optint"
  "ounit"
  "ppx_irmin"
  "ptime"
  "re"
  "repr"
  "result"
  "rresult"
  "seq"
  "sexplib0"
  "ssl"
  "stdlib-shims"
  "stringext"
  "tcpip"
  "tezos-base58"
  "tls-mirage"
  "tls"
  "topkg"
  "uri-sexp"
  "uutf"
  "webmachine"
  "yaml"
  "yojson"
  "fmt"
  "uri"
  "either"
  "uchar"
  "angstrom"
  "ppx_repr"
  "ocaml-compiler-libs"
  "ppx_derivers"
  "ppx_deriving"
  "mimic"
  "carton"
  "carton-lwt"
  "carton-git"
  "encore"
  "hxd"
  "emile"
  "psq"
  "duff"
  "pecu"
  "macaddr"
  "crunch"
  "dispatch"
  "base"
  "progress"
  "semaphore-compat"
  "lru"
  "terminal"
  "vector"
  "uucp"
  "menhir"
  "menhirLib"
  "menhirSdk"
  "biniou"
  "easy-format"
  "git-paf"
  "dns"
  "happy-eyeballs-mirage"
  "mirage-random"
  "paf"
  "httpaf"
  "h2"
  "faraday"
  "mirage-net"
  "mirage-profile"
  "ethernet"
  "arp"
  "cstruct-lwt"
  "ppx_cstruct"
  "parsexp"
  "num"
  "macaddr-cstruct"
  "lwt-dllist"
  "randomconv"
  "x509"
  "mirage-kv"
  "mirage-crypto"
  "mirage-crypto-ec"
  "mirage-crypto-pk"
  "mirage-no-solo5"
  "mirage-no-xen"
  "cstruct-sexp"
  "cstruct-unix"
  "conf-gmp-powm-sec"
  "asn1-combinators"
  "gmap"
  "pbkdf"
  "hkdf"
  "hpack"
  "mirage-runtime"
  "io-page"
  "functoria-runtime"
  "cf"
  "integers"
  "ctypes-foreign"
  "fsevents"
  "opam-format"
  "opam-state"
  "opam-core"
  "opam-file-format"
  "base-bigarray"
  "opam-repository"
  "solo5"
  "conf-libseccomp"
  "js_of_ocaml"
  "js_of_ocaml-compiler"
  "findlib_top"
  "jbuilder"
  "jst-config"
  "timezone"
  "spawn"
  "base_bigstring"
  "base_quickcheck"
  "stdio"
  "time_now"
  "octavius"
]
