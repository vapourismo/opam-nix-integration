{
  lib,
  envLib,
}: let
  scope = {
    bool = builtins.toJSON;

    string = builtins.toJSON;

    ident = f: let
      value = envLib.eval {} f;
    in
      f {
        local = {name, ...}: "${value} (= ${name})";

        package = {
          packageName,
          name,
          ...
        }: "${value} (= ${packageName}:${name})";

        combine = values:
          lib.foldl'
          (lhs: rhs: "${lhs} & ${rhs}")
          (lib.head values)
          (lib.tail values);
      };

    equal = lhs: rhs: "${lhs} == ${rhs}";

    notEqual = lhs: rhs: "${lhs} != ${rhs}";

    greaterEqual = lhs: rhs: "${lhs} >= ${rhs}";

    greaterThan = lhs: rhs: "${lhs} > ${rhs}";

    lowerEqual = lhs: rhs: "${lhs} <= ${rhs}";

    lowerThan = lhs: rhs: "${lhs} < ${rhs}";

    and = lhs: rhs: "${lhs} && ${rhs}";

    or = lhs: rhs: "${lhs} || ${rhs}";

    def = filter: "?(${show filter})";

    undef = abort "filter.undef";
  };

  show = filter: filter scope;
in
  show
