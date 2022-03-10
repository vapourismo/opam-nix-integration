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
             let body =
               OpamFilter.expand_string
                 ~partial:false
                 ~default:(fun name ->
                   "${"
                   ^ render (Filter.nix_of_ident_string (ident "__argScope") name)
                   ^ "}")
                 (fun _ -> None)
                 str
             in
             ident ("\"" ^ body ^ "\"")
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
