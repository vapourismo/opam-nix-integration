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
    }

  let ocaml_version_term =
    Arg.(info ~docv:"VERSION" [ "ocaml-version" ] |> req string |> required)
  ;;

  let file_term = Arg.(info ~docv:"PATH" [ "packages-dir" ] |> req file |> required)

  let targets_term = Arg.(info ~docv:"PACKAGE" [] |> many string |> value)

  let term =
    let combine ocaml_version packages_dir targets =
      { ocaml_version; packages_dir; targets }
    in
    Term.(const combine $ ocaml_version_term $ file_term $ targets_term)
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
  let env =
    Dir_context.std_env
      ~ocaml_native:true
      ~sys_ocaml_version:"4.13.1"
      ~arch
      ~os
      ~os_distribution:"nixos"
      ~os_family:"nixos"
      ~os_version:"1"
      ()
  in
  let constraints =
    List.filter_map
      (fun (name, constr) -> Option.map (fun constr -> name, constr) constr)
      targets
    |> OpamPackage.Name.Map.of_list
  in
  let context = Dir_context.create ~constraints ~env config.packages_dir in
  let solved = List.map (fun (name, _) -> name) targets |> Solver.solve context in
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
