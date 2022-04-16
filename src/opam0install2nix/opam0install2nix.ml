open Opam_0install
module Solver = Solver.Make (Dir_context)

module Options = struct
  open Cmdliner

  let req body infos = Arg.(opt (some body) None infos)

  let many body infos = Arg.(pos_all body [] infos)

  type t =
    { ocaml_version : string
    ; packages_dir : string
    ; targets : string list
    ; with_test : bool
    ; with_doc : bool
    }

  let ocaml_version_term =
    Arg.(info ~docv:"VERSION" [ "ocaml-version" ] |> req string |> required)
  ;;

  let file_term = Arg.(info ~docv:"PATH" [ "packages-dir" ] |> req file |> required)

  let targets_term = Arg.(info ~docv:"PACKAGE" [] |> many string |> value)

  let with_test_term = Arg.(info [ "with-test" ] |> flag |> value)

  let with_doc_term = Arg.(info [ "with-doc" ] |> flag |> value)

  let term =
    let combine ocaml_version packages_dir targets with_test with_doc =
      { ocaml_version; packages_dir; targets; with_test; with_doc }
    in
    Term.(
      const combine
      $ ocaml_version_term
      $ file_term
      $ targets_term
      $ with_test_term
      $ with_doc_term)
  ;;
end

let arch =
  match OpamSysPoll.arch () with
  | None -> failwith "Failed to discover $arch"
  | Some arch -> arch
;;

let os =
  match OpamSysPoll.os () with
  | None -> failwith "Failed to discover $os"
  | Some os -> os
;;

let parse_relop op : OpamTypes.relop option =
  match op with
  | "=" -> Some `Eq
  | "!=" -> Some `Neq
  | ">=" -> Some `Geq
  | ">" -> Some `Gt
  | "<=" -> Some `Leq
  | "<" -> Some `Lt
  | _ -> None
;;

let operator_regex = Str.regexp {|[=!<>]+|}

let parse_package_arg package_str =
  let input = String.trim package_str in
  match Str.split operator_regex input with
  | [ package; version ] ->
    let op =
      String.sub
        input
        (String.length package)
        (String.length input - (String.length version + String.length package))
    in
    (match parse_relop op with
    | Some op ->
      OpamPackage.Name.of_string package, Some (op, OpamPackage.Version.of_string version)
    | None -> failwith (Printf.sprintf "Unknown relational operator %s" op))
  | [ package ] -> OpamPackage.Name.of_string package, None
  | _ -> failwith (Printf.sprintf "Unknown package format %s" package_str)
;;

let main config =
  let open Options in
  let targets = List.map parse_package_arg config.targets in
  let target_names = List.map fst targets in
  let std_env =
    Dir_context.std_env
      ~ocaml_native:true
      ~sys_ocaml_version:config.ocaml_version
      ~arch
      ~os
      ~os_distribution:"nixos"
      ~os_family:"nixos"
      ~os_version:"1"
      ()
  in
  let env = function
    | "with-test" -> Some (OpamVariable.B config.with_test)
    | "with-doc" -> Some (OpamVariable.B config.with_doc)
    | "build" -> Some (OpamVariable.B true)
    | "post" -> Some (OpamVariable.B false)
    | "pinned" -> Some (OpamVariable.B false)
    | "dev" -> Some (OpamVariable.B true)
    | other -> std_env other
  in
  let package_constraints =
    List.filter_map
      (fun (name, constr) -> Option.map (fun constr -> name, constr) constr)
      targets
    |> OpamPackage.Name.Map.of_list
  in
  let ocaml_constraints =
    OpamPackage.Name.Map.singleton
      (OpamPackage.Name.of_string "ocaml")
      (`Eq, OpamPackage.Version.of_string config.ocaml_version)
  in
  let test_packages =
    if config.with_test then Some (OpamPackage.Name.Set.of_list target_names) else None
  in
  let context =
    Dir_context.create
      ~constraints:
        (OpamPackage.Name.Map.union (fun _ r -> r) package_constraints ocaml_constraints)
      ?test:test_packages
      ~env
      config.packages_dir
  in
  let solved = Solver.solve context target_names in
  let open Nix in
  match solved with
  | Ok selection ->
    let items =
      List.map
        (fun OpamPackage.{ name; version } ->
          OpamPackage.Name.to_string name, string (OpamPackage.Version.to_string version))
        (Solver.packages_of_result selection)
    in
    print_endline (render (attr_set items))
  | Error diag ->
    prerr_endline (Solver.diagnostics ~verbose:true diag);
    exit 1
;;

let () =
  let open Cmdliner.Term in
  (const main $ Options.term, info "opam0install2nix") |> eval |> exit
;;
