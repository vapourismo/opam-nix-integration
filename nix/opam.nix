{ lib }:
{ envLib, filterLib, constraintLib, formulaLib }:

let
  evalCommands = commands:
    let
      keptCommands = builtins.filter ({ filter, ... }: filterLib.eval filter) commands;

      prunedCommands = builtins.map
        ({ args, ... }:
          let
            keptArgs = builtins.filter ({ filter, ... }: filterLib.eval filter) args;

            prunedArgs =
              builtins.map
                ({ arg, ... }: builtins.toJSON (envLib.eval { } arg))
                keptArgs;
          in
          prunedArgs
        )
        keptCommands;
    in
    prunedCommands;

  evalFilterFormula = formulaLib.evalBoolean { atom = filterLib.eval; };

  showConstraintFormula = formulaLib.show { atom = constraintLib.show; };

  evalConstraintFormula = formulaLib.evalPredicate { atom = constraintLib.eval; };

  dependencyScope = packages: {
    package = packageName: enabled: constraints:
      if builtins.hasAttr packageName packages then
        (
          let
            package = packages.${packageName};
          in
          if evalFilterFormula enabled then
            (
              if evalConstraintFormula constraints packages.${packageName}.version then
                [ package ]
              else
                null
            )
          else
            [ ]
        )
      else
        null;

    optionalPackage = packageName: enabled: constraints:
      if builtins.hasAttr packageName packages then
        let package =
          packages.${packageName};
        in
        (
          if evalFilterFormula enabled then
            (
              if evalConstraintFormula constraints package.version then
                [ package ]
              else
                null
            )
          else
            [ ]
        )
      else
        [ ];
  };

  evalDependency = packages: f: f (dependencyScope packages);

  dependencyStringScope = packages: {
    package = packageName: enabled: constraints:
      if builtins.hasAttr packageName packages then
        (
          let package =
            packages.${packageName}.name;
          in
          if evalFilterFormula enabled then
            "${packageName}: ${showConstraintFormula constraints}"
          else
            "${packageName}: disabled"
        )
      else
        "${packageName}: unknown package";

    optionalPackage = packageName: enabled: constraints:
      if builtins.hasAttr packageName packages then
        let package =
          packages.${packageName}.name;
        in
        (
          if evalFilterFormula enabled then
            "${packageName}: ${showConstraintFormula constraints}"
          else
            "${packageName}: disabled"
        )
      else
        "${packageName}: unknown package";
  };

  showDependency = packages: f: f (dependencyStringScope packages);

  dependenciesFormulaStringScope = packages: {
    empty = "empty";

    atom = showDependency packages;
  };

  showDependenciesFormula = packages: f:
    let
      cnf = f (dependenciesFormulaStringScope packages);

      evalOrs = ors:
        if builtins.length ors > 0 then
          builtins.foldl' (lhs: rhs: "${lhs} || ${rhs}") (builtins.head ors) (builtins.tail ors)
        else
          "false";

      evalAnds = ands:
        if builtins.length ands > 0 then
          builtins.foldl' (lhs: rhs: "${lhs}\n${rhs}") (builtins.head ands) (builtins.tail ands)
        else
          "true";
    in
    evalAnds (builtins.map evalOrs cnf);

  dependenciesFormulaReduceScope = packages: {
    empty = [ ];

    atom = atom: {
      eval = evalDependency packages atom != null;
      string = showDependency packages atom;
    };
  };

  reduceDependencyFormula = packages: f:
    let
      cnf = f (dependenciesFormulaReduceScope packages);

      evalOrs =
        builtins.foldl'
          (lhs: rhs:
            if lhs.eval || rhs.eval then
              { eval = true; string = "true"; }
            else
              {
                eval = false;
                string = "${lhs.string} or \n${rhs.string}";
              }
          )
          {
            eval = false;
            string = "false";
          };

      evalAnds =
        builtins.foldl'
          (lhs: rhs:
            if lhs.eval && rhs.eval then
              {
                eval = true;
                string = "true";
              }
            else if lhs.eval then
              rhs
            else if rhs.eval then
              lhs
            else
              {
                eval = false;
                string = "${lhs.string}, \n${rhs.string}";
              }
          )
          {
            eval = true;
            string = "true";
          };

      deps = evalAnds (builtins.map evalOrs cnf);

    in
    deps.string;

  evalDependenciesFormula = name: packages: f:
    let deps = formulaLib.evalList { atom = evalDependency packages; } f; in
    if builtins.isList deps then
      deps
    else
      abort ''
        Dependency formula could not be satisfied for ${name}:
        ${reduceDependencyFormula  packages f}
      '';

  evalNativeDependencies = nativePackages: nativeDepends:
    let
      findDep = packageName:
        if builtins.hasAttr packageName nativePackages then
          nativePackages.${packageName}
        else
          abort "Unknown native package ${packageName}";
    in
    builtins.concatMap
      ({ packages, ... }: builtins.map findDep packages)
      (builtins.filter ({ filter, ... }: filterLib.eval filter) nativeDepends);

  cleanVersion = builtins.replaceStrings [ "~" ] [ "-" ];

in

{
  inherit evalDependenciesFormula evalCommands evalNativeDependencies cleanVersion;
}
