module StringSet = Set.Make (String)

module Pattern = struct
  type t =
    | PlainPat of string
    | AttrSetPat of
        { fields : StringSet.t
        ; partial : bool
        ; bound : string option
        }

  let render pat =
    match pat with
    | PlainPat name -> name
    | AttrSetPat { fields; partial; bound } ->
      let fields = StringSet.elements fields in
      let entries = if partial then fields @ [ "..." ] else fields in
      let binding = Option.fold ~none:"" ~some:(fun name -> "@" ^ name) bound in
      "{ " ^ String.concat ", " entries ^ " }" ^ binding
  ;;

  let attr_set fields =
    AttrSetPat { fields = StringSet.of_list fields; partial = false; bound = None }
  ;;

  let attr_set_partial fields = AttrSetPat { fields; partial = true; bound = None }
end

module StringMap = Map.Make (String)

type t =
  | Identifier of string
  | Bool of bool
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

let parens body = "(" ^ body ^ ")"

let rec render_prec ?(want_parens = false) exp =
  match exp with
  | Identifier ident -> ident
  | Bool value -> if value then "true" else "false"
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
    ^ String.concat
        " "
        (List.map (fun elem -> render_prec ~want_parens:true elem) elements)
    ^ "]"
  | AttrSet attrs ->
    "{ "
    ^ String.concat
        " "
        (StringMap.to_seq attrs
        |> List.of_seq
        |> List.map (fun (k, v) -> k ^ " = " ^ render_prec v ^ ";"))
    ^ " }"
  | Lambda { head; body } ->
    (if want_parens then parens else Fun.id)
    @@ Pattern.render head
    ^ ": "
    ^ render_prec body
  | Apply { func; args } ->
    (if want_parens then parens else Fun.id)
    @@ render_prec func
    ^ " "
    ^ String.concat " " (List.map (fun arg -> render_prec ~want_parens:true arg) args)

and render_segment seg =
  match seg with
  | StringSegment str -> str
  | CodeSegment code -> "${" ^ render_prec code ^ "}"
;;

let render exp = render_prec exp

let ident name = Identifier name

let attr_set entries =
  AttrSet
    (List.fold_left (fun attrs (k, v) -> StringMap.add k v attrs) StringMap.empty entries)
;;

let bool value = Bool value

let string body = String [ StringSegment body ]

let multiline lines =
  MultilineString (List.map (fun line -> [ StringSegment line ]) lines)
;;

let list elems = List elems

let lambda head body = Lambda { head; body }

let ( => ) = lambda

let apply func args = Apply { func; args }

let ( @@ ) = apply
