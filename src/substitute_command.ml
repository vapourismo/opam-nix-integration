let read_one_line () =
  try
    let line = read_line () in
    Some line
  with
  | End_of_file -> None
;;

let get_input () =
  Seq.unfold (fun () -> Option.map (fun line -> line, ()) (read_one_line ())) ()
  |> List.of_seq
  |> String.concat "\n"
;;

let main () =
  let open Nix in
  get_input () |> Env.nix_of_interpolated_string |> render |> print_endline
;;

let command = Cmdliner.Term.(const main $ const ())
