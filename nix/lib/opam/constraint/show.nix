{ filterLib }:

subject: constraint: constraint {
  equal = versionFilter: "${subject} == ${filterLib.show versionFilter}";

  notEqual = versionFilter: "${subject} != ${filterLib.show versionFilter}";

  greaterEqual = versionFilter: "${subject} >= ${filterLib.show versionFilter}";

  greaterThan = versionFilter: "${subject} > ${filterLib.show versionFilter}";

  lowerEqual = versionFilter: "${subject} <= ${filterLib.show versionFilter}";

  lowerThan = versionFilter: "${subject} < ${filterLib.show versionFilter}";
}
