let main () =
  let open Nix in
  let go (name, value) =
    match OpamVariable.to_string name, Lazy.force value with
    | ("os-distribution" as name), _ -> Some (name, string "nixos")
    | name, Some value ->
      let value =
        match value with
        | OpamVariable.B value -> bool value
        | OpamVariable.S value -> string value
        | OpamVariable.L values -> list (List.map string values)
      in
      Some (name, value)
    | _ -> None
  in
  OpamSysPoll.variables |> List.filter_map go |> attr_set |> render |> print_endline
;;

let command = Cmdliner.Term.(const main $ const ())
