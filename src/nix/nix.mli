type expr

type t = expr

val ident : string -> t

val attr_set : (string * t) list -> t

val null : t

val bool : bool -> t

val int : int -> t

val list : t list -> t

val apply : t -> t list -> t

val ( @@ ) : t -> t list -> t

val infix : t -> string -> t -> t

val unary : string -> t -> t

val index : t -> string -> t

val scoped : string -> (t -> t) -> t

val render : t -> string

module Pat : sig
  type field

  val field : string -> field

  val field_opt : string -> expr -> field

  val ( @? ) : field -> expr -> field

  type t

  val ident : string -> t

  val attr_set : field list -> t

  val attr_set_partial : field list -> t

  val render : t -> string
end

val lambda : Pat.t -> t -> t

val ( => ) : Pat.t -> t -> t

module Str : sig
  type t

  val code : expr -> t

  val str : string -> t

  val ( ^ ) : t -> t -> t

  val concat : t list -> t
end

val string : string -> t

val multiline : string list -> t

val of_str : Str.t -> t

val of_multiline_str : Str.t list -> t
