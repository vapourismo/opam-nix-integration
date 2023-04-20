{
  name,
  opam ? null,
  src ? null,
  ...
} @ args: let
  argOverride =
    if opam != null
    then {}
    else if src != null
    then {opam = "${src}/${name}.opam";}
    else abort "'opam' mustn't be null if 'src' is also null!";
in
  args // argOverride
