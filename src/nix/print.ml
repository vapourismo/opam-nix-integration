let parens body = "(" ^ body ^ ")"

let rec render_prec ?(want_parens = false) exp =
  match exp with
  | Expr.Identifier ident -> ident
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
      (Expr.StringMap.to_seq attrs
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
  | Expr.FieldPat name -> name
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
