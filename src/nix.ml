module Pattern = struct
  type t =
    | PlainPat of string
    | AttrSetPat of
        { fields : string list
        ; partial : bool
        ; bound : string option
        }

  let render pat =
    match pat with
    | PlainPat name -> name
    | AttrSetPat { fields; partial; bound } ->
      let entries = if partial then fields @ [ "..." ] else fields in
      let binding = Option.fold ~none:"" ~some:(fun name -> "@" ^ name) bound in
      "{ " ^ String.concat ", " entries ^ " }" ^ binding
  ;;

  let attr_set fields = AttrSetPat { fields; partial = false; bound = None }
end

module StringMap = Map.Make (String)

type t =
  | Identifier of string
  | String of string_segment list
  | MultilineString of string_segment list list
  | Number of Q.t
  | List of t list
  | AttrSet of attr_set
  | Lambda of
      { head : Pattern.t
      ; body : t
      }
  | Apply of
      { func : t
      ; args : t list
      }

and string_segment =
  | StringSegment of string
  | CodeSegment of t

and attr_set = t StringMap.t

let rec render exp =
  match exp with
  | Identifier ident -> ident
  | String segments ->
    [%show: string] (String.concat "" (List.map render_segment segments))
  | MultilineString lines ->
    "''"
    ^ String.concat
        "\n"
        (List.map
           (fun segments -> String.concat "" (List.map render_segment segments))
           lines)
    ^ "''"
  | Number num -> "(" ^ Q.to_string num ^ ")"
  | List elements ->
    "["
    ^ String.concat " " (List.map (fun elem -> "(" ^ render elem ^ ")") elements)
    ^ "]"
  | AttrSet attrs ->
    "{ "
    ^ String.concat
        " "
        (StringMap.to_seq attrs
        |> List.of_seq
        |> List.map (fun (k, v) -> k ^ " = " ^ render v ^ ";"))
    ^ " }"
  | Lambda { head; body } -> Pattern.render head ^ ": " ^ render body
  | Apply { func; args } ->
    "("
    ^ render func
    ^ ") "
    ^ String.concat " " (List.map (fun arg -> "(" ^ render arg ^ ")") args)

and render_segment seg =
  match seg with
  | StringSegment str -> str
  | CodeSegment code -> "${" ^ render code ^ "}"
;;

let ident name = Identifier name

let attr_set entries =
  AttrSet
    (List.fold_left (fun attrs (k, v) -> StringMap.add k v attrs) StringMap.empty entries)
;;

let string body = String [ StringSegment body ]

let multiline lines =
  MultilineString (List.map (fun line -> [ StringSegment line ]) lines)
;;

let list elems = List elems

let lambda head body = Lambda { head; body }

let apply func args = Apply { func; args }
