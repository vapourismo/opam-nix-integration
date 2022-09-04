(** Nix expression *)
type expr

type t = expr

(** [ident name] creates an expression referring to the identifier [name]. *)
val ident : string -> t

(** [attr_set fields] creates an attribute set literal with the given [fields]. *)
val attr_set : (string * t) list -> t

(** [null] is just null. *)
val null : t

(** [bool value] creates a boolean literal. *)
val bool : bool -> t

(** [int value] creates an integer literal. *)
val int : int -> t

(** [float value] creates an floating-point number literal. *)
val float : float -> t

(** [list items] creates a list literal. *)
val list : t list -> t

(** [apply f xs] applies a function [f] to arguments [xs]. *)
val apply : t -> t list -> t

(** Synonym for [apply] *)
val ( @@ ) : t -> t list -> t

(** [infix left op right] applies [left] and [right] to the given operator [op]. *)
val infix : t -> string -> t -> t

(** [unary op exp] applies the unary operator [op] to [exp]. *)
val unary : string -> t -> t

(** [index exp name] accesses the field [name] of the expression [exp]. *)
val index : t -> string -> t

(** [render exp] converts the Nix expression to string. *)
val render : t -> string

module Pat : sig
  (** Field in an attribute set pattern *)
  type field

  (** [field name] matches a mandatory field. *)
  val field : string -> field

  (** [field_opt name] matches an optional field. *)
  val field_opt : string -> expr -> field

  (** [field @? default] sets a default value for [field]. *)
  val ( @? ) : field -> expr -> field

  (** Nix pattern *)
  type t

  (** [ident name] creates a simple pattern where the value is bound to [name]. *)
  val ident : string -> t

  (** [attr_set fields] creates an attribute set pattern. *)
  val attr_set : ?bound:string -> field list -> t

  (** [attr_set_partial fields] creates an attribute set pattern with additional optional fields. *)
  val attr_set_partial : ?bound:string -> field list -> t

  (** [render pattern] converts a Nix pattern to string. *)
  val render : t -> string
end

(** [lambda pattern body] creates a function closure expression. *)
val lambda : Pat.t -> t -> t

(** Synonym for [lambda] *)
val ( => ) : Pat.t -> t -> t

(** [scoped name f] creates a lambda with a [Pat.ident] pattern. [f] is given the expression
    that represents the pattern value to construct the body. *)
val scoped : string -> (t -> t) -> t

module Str : sig
  (** Nix string *)
  type t

  (** [code exp] creates a string that interpolates a Nix expression [exp]. *)
  val code : expr -> t

  (** [str value] creates a plain string. *)
  val str : string -> t

  (** Concatenate two strings. *)
  val ( ^ ) : t -> t -> t

  (** Concatenate a list of strings. *)
  val concat : t list -> t
end

(** [string str] creates a string expression. *)
val string : string -> t

(** [multiline str] creates a multiline string expression. *)
val multiline : string list -> t

(** [of_str str] creates an expression from the given [Str.t]. *)
val of_str : Str.t -> t

(** [of_multiline_str str] creates a multiline string expression using the given [Str.t]s. *)
val of_multiline_str : Str.t list -> t
