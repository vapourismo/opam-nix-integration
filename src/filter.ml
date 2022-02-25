let eval ?(default = false) env filter = OpamFilter.eval_to_bool ~default env filter

let apply_to_list ?default env items =
  List.filter_map
    (fun (item, filter) ->
      match filter with
      | Some filter when not (eval ?default env filter) -> None
      | _ -> Some item)
    items
;;
