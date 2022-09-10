module StringSet = Set.Make (String)
module StringMap = Map.Make (String)

type expr =
  | Identifier of string
  | Bool of bool
  | String of string_segment list
  | MultilineString of string_segment list list
  | Number of Q.t
  | List of expr list
  | AttrSet of attr_set
  | Lambda of
      { head : pattern
      ; body : expr
      }
  | Apply of
      { func : expr
      ; args : expr list
      }
  | Infix of
      { left : expr
      ; op : string
      ; right : expr
      }
  | Unary of
      { op : string
      ; exp : expr
      }
  | Index of
      { attr_set : expr
      ; field : accessor
      ; default : expr option
      }

and string_segment =
  | StringSegment of string
  | CodeSegment of expr

and attr_set = expr StringMap.t

and accessor =
  | StringAccess of string
  | RedirectedAccess of expr

and field_pattern =
  | FieldPat of string
  | FieldOptPat of
      { name : string
      ; default : expr
      }

and pattern =
  | IdentPat of string
  | AttrSetPat of
      { fields : field_pattern list
      ; partial : bool
      ; bound : string option
      }

type t = expr

module Pat = struct
  type field = field_pattern

  let field name = FieldPat name

  let field_opt name default = FieldOptPat { name; default }

  let ( @? ) field default =
    match field with
    | FieldPat name | FieldOptPat { name; _ } -> FieldOptPat { name; default }
  ;;

  type t = pattern

  let attr_set ?bound fields = AttrSetPat { fields; partial = false; bound }

  let attr_set_partial ?bound fields = AttrSetPat { fields; partial = true; bound }

  let ident name = IdentPat name
end

module Str = struct
  type t = string_segment list

  let code x = [ CodeSegment x ]

  let str x = [ StringSegment x ]

  let concat = List.concat

  let ( ^ ) = ( @ )
end

let ident name = Identifier name

let attr_set entries =
  AttrSet
    (List.fold_left (fun attrs (k, v) -> StringMap.add k v attrs) StringMap.empty entries)
;;

let null = ident "null"

let bool value = Bool value

let int x = Number (Q.of_int x)

let float x = Number (Q.of_float x)

let string body = String (Str.str body)

let multiline lines = MultilineString (List.map Str.str lines)

let of_str str = String str

let of_multiline_str lines = MultilineString lines

let list elems = List elems

let lambda head body = Lambda { head; body }

let ( => ) = lambda

let apply func args = Apply { func; args }

let ( @@ ) = apply

let infix left op right = Infix { left; op; right }

let unary op exp = Unary { op; exp }

let index ?default expr field =
  Index { attr_set = expr; field = StringAccess field; default }
;;

let scoped name body = lambda (Pat.ident name) (body (ident name))
