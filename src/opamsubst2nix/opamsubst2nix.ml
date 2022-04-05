module Lib = Opam2nix_lib

let read_one_line () =
  try
    let line = read_line () in
    Some line
  with
  | End_of_file -> None
;;

let input =
  Seq.unfold (fun () -> Option.map (fun line -> line, ()) (read_one_line ())) ()
  |> List.of_seq
  |> String.concat "\n"
;;

let scope = Nix.ident "__argScope"

let segments =
  let rec with_variable head tail =
    match String.split_on_char '}' head with
    | [ name; "" ] -> Nix.CodeSegment (Lib.nix_of_ident_string scope name) :: start tail
    | _ -> failwith (Printf.sprintf "Bad variable interpolation: %s" head)
  and after_percent = function
    | [] -> []
    | head :: tail ->
      if String.starts_with ~prefix:"{" head
      then (
        let head = String.sub head 1 (String.length head - 1) in
        with_variable head tail)
      else Nix.StringSegment head :: after_percent tail
  and start segments =
    match segments with
    | head :: tail -> Nix.StringSegment head :: after_percent tail
    | [] -> []
  in
  start (String.split_on_char '%' input)
;;

let () =
  let open Nix in
  let exp = lambda (Pattern.ident "__argScope") (MultilineString [ segments ]) in
  print_endline (render exp)
;;
