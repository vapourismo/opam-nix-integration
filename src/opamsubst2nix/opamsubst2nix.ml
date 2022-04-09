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

let () =
  let open Nix in
  let exp = Lib.nix_of_interpolated_string input in
  print_endline (render exp)
;;
