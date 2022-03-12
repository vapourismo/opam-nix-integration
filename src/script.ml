let string_parser scope =
  let open Angstrom in
  let variable =
    string "%{" *> many1 (satisfy (fun c -> c <> '}'))
    <* string "}%"
    >>| fun chars ->
    List.to_seq chars
    |> String.of_seq
    |> Filter.nix_of_ident_string scope
    |> fun code -> Nix.CodeSegment code
  in
  let not_variable =
    many1 (satisfy (fun c -> c <> '%'))
    >>| fun chars ->
    List.to_seq chars |> String.of_seq |> fun str -> Nix.StringSegment str
  in
  many (variable <|> not_variable) >>| fun segments -> Nix.String segments
;;

let nix_of_args args =
  let open Nix in
  list
    (List.map
       (fun (arg, filter) ->
         let filter =
           Option.fold ~none:Filter.nix_of_true ~some:Filter.nix_of_filter filter
         in
         let arg =
           match arg with
           | OpamTypes.CString str ->
             Result.fold
               ~ok:Fun.id
               ~error:failwith
               Angstrom.(
                 parse_string ~consume:All (string_parser (ident "__argScope")) str)
           | CIdent name -> Filter.nix_of_ident_string (ident "__argScope") name
         in
         attr_set [ "filter", filter; "arg", lambda (Pattern.ident "__argScope") arg ])
       args)
;;

let nix_of_commands commands =
  let open Nix in
  list
    (List.map
       (fun (args, filter) ->
         let filter =
           Option.fold ~none:Filter.nix_of_true ~some:Filter.nix_of_filter filter
         in
         attr_set [ "filter", filter; "args", nix_of_args args ])
       commands)
;;
