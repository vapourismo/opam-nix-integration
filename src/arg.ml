let interpolate env arg = OpamFilter.expand_string ~partial:false env arg

exception UnknownVariable of string

let () =
  Printexc.register_printer (function
    | UnknownVariable name ->
      Some
        (Printf.sprintf
           "Could not find variable %s in environment"
           ([%show: string] name))
    | _ -> None)
;;

let resolve env arg =
  [%show: string]
  @@ interpolate env
  @@
  match arg with
  | OpamTypes.CString str -> str
  | OpamTypes.CIdent name ->
    (match Env.get_as_string env (Var.global name) with
    | Some str -> str
    | None -> raise (UnknownVariable name))
;;
