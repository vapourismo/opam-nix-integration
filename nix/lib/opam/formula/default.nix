{lib}: let
  evalFormula = {
    true,
    false,
    join,
    disjoin,
    atom,
  }: formula: let
    cnf = formula {
      empty = true;

      inherit atom;
    };

    evalOrs = lib.foldl' disjoin false;

    evalAnds = lib.foldl' join true;
  in
    evalAnds (lib.lists.map evalOrs cnf);

  evalListFormula = {atom}:
    evalFormula {
      true = [];

      false = null;

      join = lhs: rhs:
        if lhs != null && rhs != null
        then lhs ++ rhs
        else null;

      disjoin = lhs: rhs:
        if lhs != null && rhs != null
        then lhs ++ rhs
        else if lhs != null
        then lhs
        else rhs;

      inherit atom;
    };

  evalBooleanFormula = {atom}:
    evalFormula {
      true = true;

      false = false;

      join = lhs: rhs: lhs && rhs;

      disjoin = lhs: rhs: lhs || rhs;

      inherit atom;
    };

  evalPredicateFormula = {atom}:
    evalFormula {
      true = _: true;

      false = _: false;

      join = lhs: rhs: subject: lhs subject && rhs subject;

      disjoin = lhs: rhs: subject: lhs subject || rhs subject;

      inherit atom;
    };

  showFormula = {atom}: formula: let
    cnf = formula {
      empty = "true";

      inherit atom;
    };

    evalOrs = inputOrs:
      if lib.length inputOrs > 0
      then let
        ors = lib.filter (x: x != "true") inputOrs;
      in
        if lib.length ors > 0
        then
          lib.foldl'
          (lhs: rhs: "${lhs} || ${rhs}")
          (lib.head ors)
          (lib.tail ors)
        else "true"
      else "false";

    evalAnds = ands:
      if lib.length ands > 0
      then
        lib.foldl'
        (lhs: rhs: "${lhs} && ${rhs}")
        (lib.head ands)
        (lib.tail ands)
      else "true";
  in
    evalAnds (lib.lists.map (ors: "(${evalOrs ors})") cnf);

  debugFormula = {
    showAtom,
    evalAtom,
  }: formula: let
    cnf = formula {
      empty = {
        eval = true;
        string = "empty";
      };

      atom = atom: {
        eval = evalAtom atom;
        string = showAtom atom;
      };
    };

    evalOrs = ors:
      if lib.length ors > 0
      then let
        negativeOrs = lib.filter (o: !o.eval) ors;

        isTrue = lib.lists.any (o: o.eval) ors;
      in (
        if lib.length negativeOrs > 0 && !isTrue
        then let
          components = lib.lists.map (o: o.string) negativeOrs;
        in {
          eval = false;
          string = "(${lib.concatStringsSep " or " components})";
        }
        else {
          eval = true;
          string = "true";
        }
      )
      else {
        eval = false;
        string = "empty disjunction";
      };

    evalAnds = ands:
      lib.concatStringsSep " and " (lib.lists.map (a: a.string) (lib.filter (a: !a.eval) ands));
  in
    evalAnds (lib.lists.map evalOrs cnf);
in {
  eval = evalFormula;
  evalList = evalListFormula;
  evalBoolean = evalBooleanFormula;
  evalPredicate = evalPredicateFormula;
  show = showFormula;
  debug = debugFormula;
}
