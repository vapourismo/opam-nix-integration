let to_nix to_nix formula =
  let open Nix in
  let scope = ident "__formulaScope" in
  let rec go formula =
    match formula with
    | OpamFormula.Empty -> index scope "empty"
    | Atom atom -> index scope "atom" @@ [ to_nix atom ]
    | Block formula -> go formula
    (* The formula is in CNF, these two cases should never happen because [go] is called on
       "atom"-like items of the formula. *)
    | And _ -> failwith "CNF conversion failed!"
    | Or _ -> failwith "CNF conversion failed!"
  in
  let body =
    OpamFormula.cnf_of_formula formula
    |> OpamFormula.ands_to_list
    |> List.map (fun ors -> OpamFormula.ors_to_list ors |> List.map go |> list)
    |> list
  in
  lambda (Pattern.ident "__formulaScope") body
;;
