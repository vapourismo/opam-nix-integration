type t = OpamFilter.env

module Map = OpamVariable.Full.Map

let resolve_scoped var =
  let prefix =
    "$"
    ^ Option.fold
        ~none:"out"
        ~some:(fun name ->
          (* TODO: Fix this placeholder *)
          "{" ^ OpamPackage.Name.to_string name ^ "}")
        (OpamVariable.Full.package var)
  in
  let sub_prefix dir = Some (Var.string (prefix ^ "/" ^ dir)) in
  let local_name = OpamVariable.to_string (OpamVariable.Full.variable var) in
  match local_name with
  | "prefix" -> Some (Var.string prefix)
  | "bin" | "sbin" | "etc" | "share" | "lib" -> sub_prefix local_name
  | "doc" | "man" -> sub_prefix ("share/" ^ local_name)
  | _ -> None
;;

(* Option.bind (OpamVariable.Full.package var) (fun pkg -> __) *)

let create entries =
  let map = Map.of_list entries in
  fun var ->
    match resolve_scoped var with
    | None -> Map.find_opt var map
    | result -> result
;;

let get_as_string env key = Option.map OpamVariable.string_of_variable_contents (env key)

let set key value = Map.add key value
