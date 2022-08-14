module StringSet = Set.Make (String)
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
      { head : pattern
      ; body : t
      }
  | Apply of
      { func : t
      ; args : t list
      }
  | Infix of
      { left : t
      ; op : string
      ; right : t
      }
  | Unary of
      { op : string
      ; exp : t
      }
  | Index of
      { attr_set : t
      ; field : accessor
      }

and string_segment =
  | StringSegment of string
  | CodeSegment of t

and attr_set = t StringMap.t

and accessor =
  | StringAccess of string
  | RedirectedAccess of t

and field_pattern =
  | FieldPat of string
  | FieldOptPat of
      { name : string
      ; default : t
      }

and pattern =
  | IdentPat of string
  | AttrSetPat of
      { fields : field_pattern list
      ; partial : bool
      ; bound : string option
      }

let parens body = "(" ^ body ^ ")"

let rec render_prec ?(want_parens = false) exp =
  match exp with
  | Identifier ident -> ident
  | Bool value -> if value then "true" else "false"
  | String segments -> render_string segments
  | MultilineString lines -> render_multline_string lines
  | Number num -> "(" ^ Q.to_string num ^ ")"
  | List elements -> render_list elements
  | AttrSet attrs -> render_attrs attrs
  | Lambda { head; body } ->
    (if want_parens then parens else Fun.id)
    @@ render_pattern head
    ^ ": "
    ^ render_prec body
  | Apply { func; args } ->
    (if want_parens then parens else Fun.id)
    @@ render_prec func
    ^ " "
    ^ String.concat " " (List.map (fun arg -> render_prec ~want_parens:true arg) args)
  | Unary { op; exp } -> op ^ render_prec ~want_parens:true exp
  | Infix { left; op; right } ->
    (if want_parens then parens else Fun.id)
    @@ render_prec ~want_parens:true left
    ^ " "
    ^ op
    ^ " "
    ^ render_prec ~want_parens:true right
  | Index { attr_set; field } ->
    render_prec ~want_parens:true attr_set ^ "." ^ render_accessor field

and render_string segments =
  "\""
  ^ String.concat "" (List.map (fun seg -> render_string_segment seg) segments)
  ^ "\""

and render_multline_string lines =
  "''"
  ^ String.concat
      "\n"
      (List.map
         (fun segments ->
           String.concat
             ""
             (List.map (fun seg -> render_string_segment ~escape:false seg) segments))
         lines)
  ^ "''"

and render_string_segment ?(escape = true) seg =
  match seg with
  | StringSegment str ->
    if escape then String.concat "\\\"" (String.split_on_char '"' str) else str
  | CodeSegment code -> "${" ^ render_prec code ^ "}"

and render_list elements =
  "["
  ^ String.concat " " (List.map (fun elem -> render_prec ~want_parens:true elem) elements)
  ^ "]"

and render_attrs attrs =
  "{ "
  ^ String.concat
      " "
      (StringMap.to_seq attrs
      |> List.of_seq
      |> List.map (fun (k, v) ->
             render_string [ StringSegment k ] ^ " = " ^ render_prec v ^ ";"))
  ^ " }"

and render_accessor acc =
  match acc with
  | StringAccess name -> name
  | RedirectedAccess expr -> "${" ^ render_prec expr ^ "}"

and render_field_pattern field_pat =
  match field_pat with
  | FieldPat name -> name
  | FieldOptPat { name; default } -> name ^ " ? " ^ render_prec default

and render_pattern pat =
  match pat with
  | IdentPat name -> name
  | AttrSetPat { fields; partial; bound } ->
    let fields = List.map render_field_pattern fields in
    let entries = if partial then fields @ [ "..." ] else fields in
    let binding = Option.fold ~none:"" ~some:(fun name -> "@" ^ name) bound in
    "{ " ^ String.concat ", " entries ^ " }" ^ binding
;;

let render exp = render_prec exp

module Pattern = struct
  type field = field_pattern

  let field name = FieldPat name

  let field_opt name default = FieldOptPat { name; default }

  let ( @? ) field default =
    match field with
    | FieldPat name | FieldOptPat { name; _ } -> FieldOptPat { name; default }
  ;;

  type t = pattern

  let attr_set fields = AttrSetPat { fields; partial = false; bound = None }

  let attr_set_partial fields = AttrSetPat { fields; partial = true; bound = None }

  let ident name = IdentPat name
end

let ident name = Identifier name

let attr_set entries =
  AttrSet
    (List.fold_left (fun attrs (k, v) -> StringMap.add k v attrs) StringMap.empty entries)
;;

let null = ident "null"

let bool value = Bool value

let int x = Number (Q.of_int x)

let string body = String [ StringSegment body ]

let multiline lines =
  MultilineString (List.map (fun line -> [ StringSegment line ]) lines)
;;

let list elems = List elems

let lambda head body = Lambda { head; body }

let ( => ) = lambda

let apply func args = Apply { func; args }

let ( @@ ) = apply

let infix left op right = Infix { left; op; right }

let unary op exp = Unary { op; exp }

let index expr field = Index { attr_set = expr; field = StringAccess field }

let scoped name body = lambda (Pattern.ident name) (body (ident name))
