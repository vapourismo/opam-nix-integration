let pp_parens pp fmt = Format.fprintf fmt "(%a)" pp

let pp_join ?(sep = "") pp fmt args =
  match args with
  | h :: t ->
    pp fmt h;
    List.iter (fun x -> Format.fprintf fmt "%s%a" sep pp x) t
  | _ -> Format.pp_print_string fmt ""
;;

let rec pp_prec ?(want_parens = false) fmt exp =
  match exp with
  | Expr.Identifier ident -> Format.pp_print_string fmt ident
  | Bool value -> Format.pp_print_string fmt (if value then "true" else "false")
  | String segments -> pp_string fmt segments
  | MultilineString lines -> pp_multline_string fmt lines
  | Number num -> Format.fprintf fmt "(%a)" Q.pp_print num
  | List elements -> pp_list fmt elements
  | AttrSet attrs -> pp_attrs fmt attrs
  | Lambda { head; body } ->
    (if want_parens then pp_parens else Fun.id)
      (fun fmt () ->
        Format.fprintf fmt "%a: %a" pp_pattern head (pp_prec ?want_parens:None) body)
      fmt
      ()
  | Apply { func; args } ->
    (if want_parens then pp_parens else Fun.id)
      (fun fmt () ->
        Format.fprintf
          fmt
          "%a %a"
          (pp_prec ?want_parens:None)
          func
          (pp_join ~sep:" " (pp_prec ~want_parens:true))
          args)
      fmt
      ()
  | Unary { op; exp } -> Format.fprintf fmt "%s%a" op (pp_prec ~want_parens:true) exp
  | Infix { left; op; right } ->
    (if want_parens then pp_parens else Fun.id)
      (fun fmt () ->
        Format.fprintf
          fmt
          "%a %s %a"
          (pp_prec ~want_parens:true)
          left
          op
          (pp_prec ~want_parens:true)
          right)
      fmt
      ()
  | Index { attr_set; field; default = None } ->
    Format.fprintf fmt "%a.%a" (pp_prec ~want_parens:true) attr_set pp_accessor field
  | Index { attr_set; field; default = Some default } ->
    (if want_parens then pp_parens else Fun.id)
      (fun fmt () ->
        Format.fprintf
          fmt
          "%a.%a or %a"
          (pp_prec ~want_parens:true)
          attr_set
          pp_accessor
          field
          (pp_prec ~want_parens:true)
          default)
      fmt
      ()

and pp_string_segment ?(escape = true) fmt seg =
  match seg with
  | Expr.StringSegment str ->
    if escape
    then pp_join ~sep:"\\\"" Format.pp_print_string fmt (String.split_on_char '"' str)
    else Format.pp_print_string fmt str
  | CodeSegment code -> Format.fprintf fmt "${%a}" (pp_prec ?want_parens:None) code

and pp_string fmt segments =
  Format.fprintf fmt "\"%a\"" (pp_join pp_string_segment) segments

and pp_multline_string fmt lines =
  Format.fprintf
    fmt
    "''%a''"
    (pp_join ~sep:"\n" (pp_join (pp_string_segment ~escape:false)))
    lines

and pp_list fmt elements =
  Format.fprintf fmt "[%a]" (pp_join ~sep:" " (pp_prec ~want_parens:true)) elements

and pp_attrs fmt attrs =
  let pp_kv fmt (k, v) =
    Format.fprintf
      fmt
      "%a = %a;"
      pp_string
      [ StringSegment k ]
      (pp_prec ?want_parens:None)
      v
  in
  Format.fprintf
    fmt
    "{ %a }"
    (pp_join ~sep:" " pp_kv)
    (attrs |> Expr.StringMap.to_seq |> List.of_seq)

and pp_accessor fmt acc =
  match acc with
  | StringAccess name -> pp_string fmt [ Expr.StringSegment name ]
  | RedirectedAccess expr -> Format.fprintf fmt "${%a}" (pp_prec ?want_parens:None) expr

and pp_field_pattern fmt field_pat =
  match field_pat with
  | Expr.FieldPat name -> Format.pp_print_string fmt name
  | FieldOptPat { name; default } ->
    Format.fprintf fmt "%s ? %a" name (pp_prec ?want_parens:None) default

and pp_pattern fmt pat =
  match pat with
  | IdentPat name -> Format.pp_print_string fmt name
  | AttrSetPat { fields; partial; bound } ->
    let pp_fields fmt = pp_join ~sep:", " pp_field_pattern fmt fields in
    let pp_partial fmt =
      match fields, partial with
      | [], true -> Format.fprintf fmt "{ ... }"
      | _, true -> Format.fprintf fmt "{ %t, ... }" pp_fields
      | _, false -> Format.fprintf fmt "{ %t }" pp_fields
    in
    (match bound with
     | None -> pp_partial fmt
     | Some name -> Format.fprintf fmt "%t@%s" pp_partial name)
;;

let render_pattern pat = Format.asprintf "%a" pp_pattern pat

let render pat = Format.asprintf "%a" (pp_prec ?want_parens:None) pat
