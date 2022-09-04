let is_bad_prefix char =
  let alpha = ('a' <= char && char <= 'z') || ('A' <= char && char <= 'Z') in
  not (alpha || char = '_')
;;

let replace_bad_chars string =
  String.map
    (function
       | '+' -> 'p'
       | c -> c)
    string
;;

let string_of_package_name name =
  let name = OpamPackage.Name.to_string name in
  if String.length name > 0 && is_bad_prefix (String.get name 0)
  then "_" ^ replace_bad_chars name
  else replace_bad_chars name
;;
