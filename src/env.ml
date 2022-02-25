type t = OpamFilter.env

module Map = OpamVariable.Full.Map

let create entries =
  let map = Map.of_list entries in
  fun var -> Map.find_opt var map
;;

let get_as_string env key = Option.map OpamVariable.string_of_variable_contents (env key)
