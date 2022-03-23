module Lib = Opam2nix_lib

let read_one_line () =
  try
    let line = read_line () in
    Some line
  with
  | End_of_file -> None
;;

let lines =
  Seq.unfold (fun () -> Option.map (fun line -> line, ()) (read_one_line ())) ()
  |> List.of_seq
  |> String.concat "\n"
;;

let () =
  let expr =
    Result.fold ~ok:Fun.id ~error:failwith
    @@ Angstrom.(
         parse_string
           ~consume:All
           (Lib.interpolated_string_parser (Nix.ident "__argScope"))
           lines)
  in
  let lambda = Nix.(lambda (Pattern.ident "__argScope") expr) in
  print_string (Nix.render lambda)
;;
