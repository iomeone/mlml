external print_int : int -> unit = "_mlml_print_int"
external print_char : char -> unit = "_mlml_print_char"
external print_string : string -> unit = "_mlml_print_string"
external int_of_char : char -> int = "_mlml_identity"
external char_of_int : int -> char = "_mlml_identity"
external _append_string : string * string -> string = "_mlml_append_string"
external exit : int -> 'a = "_mlml_exit"

let not c = if c then false else true
let ( <> ) a b = not (a = b)
let ( == ) a b = not (a != b)
let ( ^ ) a b = _append_string (a, b)
let ( <= ) a b = not (a > b)
let ( >= ) a b = not (a < b)
let rec ( @ ) a b = match a with [] -> b | h :: t -> h :: (t @ b)

(* TODO: @@ is right-assiciative *)
let ( @@ ) f a = f a
let ( |> ) v f = f v
