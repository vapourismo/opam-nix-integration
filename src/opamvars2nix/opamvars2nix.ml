let () =
  let open Nix in
  let go (name, value) =
    Option.map
      (fun value ->
        let value =
          match value with
          | OpamVariable.B value -> bool value
          | OpamVariable.S value -> string value
          | OpamVariable.L values -> list (List.map string values)
        in
        OpamVariable.to_string name, value)
      (Lazy.force value)
  in
  OpamSysPoll.variables |> List.filter_map go |> attr_set |> render |> print_endline
;;
