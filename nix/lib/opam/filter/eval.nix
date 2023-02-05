{envLib}: let
  scope = let
    self = {allowMissing ? false}: {
      # bool -> bool
      bool = value: value;

      # string -> string
      string = value: value;

      # env -> any
      ident = envLib.eval {
        onMissing =
          if allowMissing
          then _: _: null
          else envLib.defaultOnMissing;
      };

      # any -> any -> bool
      equal = lhs: rhs:
        if lhs == null || rhs == null
        then null
        else lhs == rhs;

      # any -> any -> bool
      notEqual = lhs: rhs:
        if lhs == null || rhs == null
        then null
        else lhs != rhs;

      # any -> any -> bool
      greaterEqual = lhs: rhs:
        if lhs == null || rhs == null
        then null
        else lhs >= rhs;

      # any -> any -> bool
      greaterThan = lhs: rhs:
        if lhs == null || rhs == null
        then null
        else lhs > rhs;

      # any -> any -> bool
      lowerEqual = lhs: rhs:
        if lhs == null || rhs == null
        then null
        else lhs <= rhs;

      # any -> any -> bool
      lowerThan = lhs: rhs:
        if lhs == null || rhs == null
        then null
        else lhs < rhs;

      # bool -> bool -> bool
      and = lhs: rhs:
        if (lhs == null && rhs == false) || (rhs == null && lhs == false)
        then false
        else lhs && rhs;

      # bool -> bool -> bool
      or = lhs: rhs:
        if (lhs == null && rhs == true) || (rhs == null && lhs == true)
        then true
        else lhs || rhs;

      # bool -> bool
      not = x: !x;

      # filter -> bool
      def = filter: filter (self {allowMissing = true;}) != null;

      # ?
      undef = abort "Bad use of filter.undef!";
    };
  in
    self;
in
  filter: filter (scope {})
