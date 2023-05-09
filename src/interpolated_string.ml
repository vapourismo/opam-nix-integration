(** This module deals with interpolated strings that may apear in OPAM files. *)

(** [parse ~on_string ~on_variable input] parses an interpolated string into a list.

    Take for example the following snippet.

    {[
      parse ~on_string ~on_variable "Hello, %{world}%!"
    ]}

    It will effectively transform into this:

    {[
      [on_string "Hello, "; on_variable "world"; on_string "!"]
    ]}
*)
let parse ~on_string ~on_variable input =
  let rec start_variable head =
    (* At this point we parsed the "%{" leading up to the variable name.
       That means [head] should contain the variable name and a closing "}" but not the trailing
       "%" because that was used earlier to split the segments.
     *)
    match String.split_on_char '}' head with
    | [ name; "" ] -> on_variable name
    | _ -> failwith (Printf.sprintf "Bad variable interpolation: %s" head)
  and after_percent tail k =
    match tail with
    | [] -> k []
    | head :: tail ->
      if String.starts_with ~prefix:"{" head
      then (
        (* If [head] starts with a "{" that means the entire preamble before splitting was "%{"
           which indicates a variable interpolation. *)
        let body =
          (* Remove the prefix "{". Despite the entire interpolation expression ending in "}%" we
             don't have to remove any more characters here: "%" was removed due to prior splitting
             and the closing "}" is deal with by [start_variable]. *)
          String.sub head 1 (String.length head - 1)
        in
        let var = start_variable body in
        start tail (fun xs -> k (var :: xs)))
      else (
        let body =
          (* If [head] is empty, we've encountered a "%%" sequence. The following "%" will trigger
             the production of "%" in the resulting string. *)
          if String.length head > 0 then "%" ^ head else head
        in
        let str = on_string body in
        after_percent tail (fun xs -> k (str :: xs)))
  and start segments k =
    match segments with
    | head :: tail ->
      (* [head] is the string leading up to the first "%". [tail] are the segments between "%"s. *)
      let str = on_string head in
      after_percent tail (fun xs -> k (str :: xs))
    | [] -> k []
  in
  start (String.split_on_char '%' input) Fun.id
;;
