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
       "%" because that was used earlier to split the segments. [tail] represents the segments after
       the trailing "%".
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
        let head = String.sub head 1 (String.length head - 1) in
        let var = start_variable head in
        start tail (fun xs -> k (var :: xs)))
      else (
        let str = on_string (if String.length head > 0 then "%" ^ head else head) in
        after_percent tail (fun xs -> k (str :: xs)))
  and start segments k =
    match segments with
    | head :: tail ->
      let str = on_string head in
      after_percent tail (fun xs -> k (str :: xs))
    | [] -> k []
  in
  start (String.split_on_char '%' input) Fun.id
;;
