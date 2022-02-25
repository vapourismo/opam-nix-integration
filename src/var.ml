type t = OpamVariable.Full.t

let global name = OpamVariable.Full.global (OpamVariable.of_string name)

let self name = OpamVariable.Full.self (OpamVariable.of_string name)

let foreign package name =
  OpamVariable.Full.create
    (OpamPackage.Name.of_string package)
    (OpamVariable.of_string name)
;;

let string = OpamVariable.string

let bool = OpamVariable.bool

let list items = OpamVariable.L items
