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
  ocaml-src = final.opamPackages.ocaml-src.${final.ocaml.version};

  dune = final.opamPackages.dune."2.9.3";
  dune-configurator = final.opamPackages.dune-configurator.${final.dune.version};

  ocamlbuild = final.opamPackages.ocamlbuild.latest;

  camlp4 = final.opamPackages.camlp4."4.13+1";

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

  digestif =
    final.callOpam
      {
        name = "digestif";
        version = "1.1.0";
        patches = [ ../patches/digestif-1.1.0.patch ];
      }
      { };

  # Packages where the latest version is not viable.
  ppxlib = final.opamPackages.ppxlib."0.24.0";
  hxd = final.opamPackages.hxd."0.3.1";
  cstruct = final.opamPackages.cstruct."6.0.1";

  git = final.opamPackages.git."3.8.0";
  git-unix = final.opamPackages.git-unix.${final.git.version};
  git-mirage = final.opamPackages.git-mirage.${final.git.version};
  git-paf = final.opamPackages.git-paf.${final.git.version};

  happy-eyeballs = final.opamPackages.happy-eyeballs."0.1.3";
  happy-eyeballs-lwt = final.opamPackages.happy-eyeballs-lwt.${final.happy-eyeballs.version};
  happy-eyeballs-mirage = final.opamPackages.happy-eyeballs-mirage.${final.happy-eyeballs.version};

  cf = final.opamPackages.cf."0.4";
  cf-lwt = final.opamPackages.cf-lwt.${final.cf.version};

  cstruct-lwt = final.opamPackages.cstruct-lwt.${final.cstruct.version};
  cstruct-sexp = final.opamPackages.cstruct-sexp.${final.cstruct.version};
  cstruct-unix = final.opamPackages.cstruct-unix.${final.cstruct.version};
  ppx_cstruct = final.opamPackages.ppx_cstruct.${final.cstruct.version};

  # These packages have messed up versions published.
  ppx_sexp_conv = final.opamPackages.ppx_sexp_conv."v0.15.0";
  sexplib = final.opamPackages.sexplib."v0.15.0";
  core = final.opamPackages.core."v0.15.0";
  core_kernel = final.opamPackages.core_kernel."v0.15.0";
  core_bench = final.opamPackages.core_bench."v0.15.0";
  ppx_jane = final.opamPackages.ppx_jane."v0.15.0";
  bin_prot = final.opamPackages.bin_prot."v0.15.0";
  fieldslib = final.opamPackages.fieldslib."v0.15.0";
  jane-street-headers = final.opamPackages.jane-street-headers."v0.15.0";
  ppx_assert = final.opamPackages.ppx_assert."v0.15.0";
  ppx_base = final.opamPackages.ppx_base."v0.15.0";
  ppx_hash = final.opamPackages.ppx_hash."v0.15.0";
  ppx_inline_test = final.opamPackages.ppx_inline_test."v0.15.0";
  ppx_sexp_message = final.opamPackages.ppx_sexp_message."v0.15.0";
  splittable_random = final.opamPackages.splittable_random."v0.15.0";
  typerep = final.opamPackages.typerep."v0.15.0";
  variantslib = final.opamPackages.variantslib."v0.15.0";
  ppx_optcomp = final.opamPackages.ppx_optcomp."v0.15.0";
  ppx_bench = final.opamPackages.ppx_bench."v0.15.0";
  ppx_bin_prot = final.opamPackages.ppx_bin_prot."v0.15.0";
  ppx_custom_printf = final.opamPackages.ppx_custom_printf."v0.15.0";
  ppx_expect = final.opamPackages.ppx_expect."v0.15.0";
  ppx_fields_conv = final.opamPackages.ppx_fields_conv."v0.15.0";
  ppx_here = final.opamPackages.ppx_here."v0.15.0";
  ppx_let = final.opamPackages.ppx_let."v0.15.0";
  ppx_module_timer = final.opamPackages.ppx_module_timer."v0.15.0";
  ppx_optional = final.opamPackages.ppx_optional."v0.15.0";
  ppx_pipebang = final.opamPackages.ppx_pipebang."v0.15.0";
  ppx_sexp_value = final.opamPackages.ppx_sexp_value."v0.15.0";
  ppx_stable = final.opamPackages.ppx_stable."v0.15.0";
  ppx_typerep_conv = final.opamPackages.ppx_typerep_conv."v0.15.0";
  ppx_string = final.opamPackages.ppx_string."v0.15.0";
  ppx_variants_conv = final.opamPackages.ppx_variants_conv."v0.15.0";
  ppx_cold = final.opamPackages.ppx_cold."v0.15.0";
  ppx_compare = final.opamPackages.ppx_compare."v0.15.0";
  ppx_enumerate = final.opamPackages.ppx_enumerate."v0.15.0";
  ppx_js_style = final.opamPackages.ppx_js_style."v0.15.0";
  ppx_fixed_literal = final.opamPackages.ppx_fixed_literal."v0.15.0";
} // selectLatest [
  "alcotest-lwt"
  "alcotest"
  "angstrom"
  "arp"
  "asn1-combinators"
  "astring"
  "awa-mirage"
  "awa"
  "base_bigstring"
  "base_quickcheck"
  "base-bigarray"
  "base-bytes"
  "base-threads"
  "base-unix"
  "base"
  "base64"
  "bechamel-notty"
  "bechamel-perf"
  "bechamel"
  "bheap"
  "bigarray-compat"
  "bigstringaf"
  "biniou"
  "bisect_ppx"
  "bos"
  "ca-certs-nss"
  "ca-certs"
  "camlzip"
  "carton-git"
  "carton-lwt"
  "carton"
  "cinaps"
  "cohttp-lwt-unix"
  "cohttp-lwt"
  "cohttp"
  "conduit-lwt-unix"
  "conduit-lwt"
  "conduit"
  "conf-gmp-powm-sec"
  "conf-gmp"
  "conf-libffi"
  "conf-libseccomp"
  "conf-libssl"
  "conf-m4"
  "conf-ncurses"
  "conf-perl"
  "conf-pkg-config"
  "cppo"
  "crowbar"
  "crunch"
  "csexp"
  "ctypes-foreign"
  "ctypes"
  "decompress"
  "dispatch"
  "dns-client"
  "dns"
  "domain-name"
  "duff"
  "duration"
  "easy-format"
  "either"
  "emile"
  "encore"
  "eqaf"
  "ethernet"
  "ezjsonm"
  "faraday"
  "fileutils"
  "findlib_top"
  "fmt"
  "fpath"
  "fsevents-lwt"
  "fsevents"
  "functoria-runtime"
  "gmap"
  "graphics"
  "graphql_parser"
  "graphql-cohttp"
  "graphql-lwt"
  "graphql"
  "h2"
  "hex"
  "hkdf"
  "hpack"
  "httpaf"
  "index"
  "inotify"
  "integers"
  "io-page"
  "ipaddr-cstruct"
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
  "jbuilder"
  "js_of_ocaml-compiler"
  "js_of_ocaml"
  "jsonm"
  "jst-config"
  "junit_alcotest"
  "ke"
  "logs"
  "lru"
  "lwt_log"
  "lwt_ppx"
  "lwt_ssl"
  "lwt-dllist"
  "lwt"
  "macaddr-cstruct"
  "macaddr"
  "magic-mime"
  "mdx"
  "menhir"
  "menhirLib"
  "menhirSdk"
  "metrics-unix"
  "metrics"
  "mimic"
  "mirage-clock-unix"
  "mirage-clock"
  "mirage-crypto-ec"
  "mirage-crypto-pk"
  "mirage-crypto-rng"
  "mirage-crypto"
  "mirage-flow"
  "mirage-kv-mem"
  "mirage-kv"
  "mirage-mmap"
  "mirage-net"
  "mirage-no-solo5"
  "mirage-no-xen"
  "mirage-profile"
  "mirage-random-test"
  "mirage-random"
  "mirage-runtime"
  "mirage-time-unix"
  "mirage-time"
  "mirage-unix"
  "mirage-vnetif"
  "mmap"
  "monolith"
  "mtime"
  "num"
  "ocaml-compiler-libs"
  "ocaml-migrate-parsetree"
  "ocaml-syntax-shims"
  "ocaml-version"
  "ocamlgraph"
  "ocplib-endian"
  "ocplib-json-typed"
  "octavius"
  "odoc-parser"
  "odoc"
  "opam-core"
  "opam-file-format"
  "opam-format"
  "opam-repository"
  "opam-state"
  "optint"
  "ounit"
  "ounit2"
  "paf"
  "parsexp"
  "pbkdf"
  "pcap-format"
  "pecu"
  "pprint"
  "ppx_derivers"
  "ppx_deriving_yojson"
  "ppx_deriving"
  "ppx_irmin"
  "ppx_repr"
  "progress"
  "psq"
  "ptime"
  "qcheck-alcotest"
  "qcheck-core"
  "qcheck"
  "qtest"
  "randomconv"
  "re"
  "repr"
  "result"
  "rresult"
  "semaphore-compat"
  "seq"
  "sexplib0"
  "solo5"
  "spawn"
  "ssl"
  "stdio"
  "stdlib-shims"
  "stringext"
  "tcpip"
  "terminal"
  "tezos-base58"
  "time_now"
  "timezone"
  "tls-mirage"
  "tls"
  "topkg"
  "uchar"
  "uri-sexp"
  "uri"
  "uucd"
  "uucp"
  "uunf"
  "uutf"
  "vector"
  "webmachine"
  "x509"
  "yaml"
  "yojson"
]
