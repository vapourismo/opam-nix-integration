open Opam_0install
module Solver = Solver.Make (Dir_context)

module Options = struct
  open Cmdliner

  let option body infos = Arg.(opt (some body) None infos)

  let many body infos = Arg.(pos_all body [] infos)

  type t =
    { packages_dir : string
    ; targets : string list
    ; test_targets : string list
    ; pins : string list
    }

  let file_term = Arg.(info ~docv:"PATH" [ "packages-dir" ] |> option file |> required)

  let test_targets =
    Arg.(info ~docv:"PACKAGE" [ "with-test-for" ] |> opt_all string [] |> value)
  ;;

  let pins = Arg.(info ~docv:"FILE" [ "pin" ] |> opt_all string [] |> value)

  let targets_term = Arg.(info ~docv:"PACKAGE" [] |> many string |> value)

  let term =
    let combine packages_dir targets test_targets pins =
      { packages_dir; targets; test_targets; pins }
    in
    Term.(const combine $ file_term $ targets_term $ test_targets $ pins)
  ;;
end

let arch =
  match OpamSysPoll.arch OpamVariable.Map.empty with
  | None -> failwith "Failed to discover $arch"
  | Some arch -> arch
;;

let os =
  match OpamSysPoll.os OpamVariable.Map.empty with
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
    let package = String.trim package in
    let version = String.trim version in
    (match parse_relop op with
     | Some op ->
       OpamPackage.Name.of_string package, Some (op, OpamPackage.Version.of_string version)
     | None -> failwith (Printf.sprintf "Unknown relational operator %s" op))
  | [ package ] ->
    let package = String.trim package in
    OpamPackage.Name.of_string package, None
  | _ -> failwith (Printf.sprintf "Unknown package format %s" package_str)
;;

let read_opam path = path |> OpamFile.make |> OpamFile.OPAM.read

let main config =
  let open Options in
  let targets = List.map parse_package_arg config.targets in
  let target_names = List.map fst targets in
  let lookup_std_env =
    Dir_context.std_env
      ~ocaml_native:true
      ~arch
      ~os
      ~os_distribution:"nixos"
      ~os_family:"nixos"
      ~os_version:"1"
      ()
  in
  let lookup_env = function
    | "build" -> Some (OpamVariable.B true)
    | "post" -> Some (OpamVariable.B false)
    | "pinned" -> Some (OpamVariable.B false)
    | "dev" -> Some (OpamVariable.B true)
    | other -> lookup_std_env other
  in
  let package_constraints =
    List.filter_map
      (fun (name, constr) -> Option.map (fun constr -> name, constr) constr)
      targets
    |> OpamPackage.Name.Map.of_list
  in
  let test_packages =
    List.map OpamPackage.Name.of_string config.test_targets
    |> OpamPackage.Name.Set.of_list
  in
  let pins =
    List.map
      (fun path ->
        let opt_name, path =
          match String.split_on_char ':' path with
          | [ name; path ] ->
            Some (String.trim name |> OpamPackage.Name.of_string), String.trim path
          | _ -> None, path
        in
        let opam = read_opam (OpamFilename.of_string path) in
        let name =
          match opam.name, opt_name with
          | Some name, _ | None, Some name -> name
          | None, None ->
            failwith
              (Format.asprintf
                 "Cannot pin a package without a name: %s.\n\
                  Consider prefixing the argument to --pin with 'name:' to override the \
                  OPAM description name."
                 path)
        in
        let version =
          Option.value ~default:(OpamPackage.Version.of_string "pinned") opam.version
        in
        name, (version, opam))
      config.pins
  in
  let pins = OpamPackage.Name.Map.of_list pins in
  let constraints =
    let open OpamPackage.Name.Map in
    map (fun (version, _) -> `Eq, version) pins
    |> union (fun _ rhs -> rhs) package_constraints
  in
  let context =
    Dir_context.create
      ~constraints
      ~test:test_packages
      ~env:lookup_env
      ~pins
      config.packages_dir
  in
  let solved = Solver.solve context (target_names @ OpamPackage.Name.Map.keys pins) in
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

let command = Cmdliner.Term.(const main $ Options.term)
