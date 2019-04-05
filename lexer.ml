type token =
  | IntLiteral of int
  | CapitalIdent of string
  | LowerIdent of string
  | Plus
  | Star
  | Let
  | In
  | Equal

let to_digit c = int_of_char c - int_of_char '0'

let string_of_chars chars =
  let buf = Buffer.create 8 in
  List.iter (Buffer.add_char buf) chars;
  Buffer.contents buf

let rec read_int acc rest =
  match rest with
  | h :: t -> (
    match h with
    | '0' .. '9' -> read_int (acc * 10 + to_digit h) t
    | _ -> (rest, acc)
  )
  | _ -> ([], acc)

let rec read_ident acc rest =
  match rest with
  | h :: t -> (
    match h with
    | 'a' .. 'z' | 'A' .. 'Z' | '_' -> read_ident (h :: acc) t
    | _ -> (rest, acc)
  )
  | _ -> ([], acc)

let rec tokenize_aux acc rest =
  match rest with
  | [] -> acc
  | h :: t ->
    match h with
    | ' ' | '\t' | '\n' -> tokenize_aux acc t
    | '0' .. '9' -> (
      let rest, num = read_int 0 rest in
      tokenize_aux (IntLiteral num :: acc) rest
    )
    | 'a' .. 'z' | 'A' .. 'Z' | '_' -> (
      let rest, ident = read_ident [] rest in
      let ident_str = string_of_chars ident in
      match ident_str with
      | "let" -> tokenize_aux (Let :: acc) rest
      | "in" -> tokenize_aux (In :: acc) rest
      | _ -> failwith @@ Printf.sprintf "unexpected idenfitier: '%s'" ident_str
    )
    | '+' -> tokenize_aux (Plus :: acc) t
    | '*' -> tokenize_aux (Star :: acc) t
    | '=' -> tokenize_aux (Equal :: acc) t
    | _ -> failwith @@ Printf.sprintf "unexpected character: '%c'" h

let explode s =
  let rec exp i l =
    if i < 0 then l else exp (i - 1) (s.[i] :: l) in
  exp (String.length s - 1) []

let tokenize source =
  tokenize_aux [] @@ explode source |> List.rev

let token_to_string = function
  | IntLiteral num -> string_of_int num
  | CapitalIdent ident | LowerIdent ident -> ident
  | Plus -> "+"
  | Star -> "*"
  | Let -> "let"
  | In -> "in"
  | Equal -> "="

let tokens_to_string tokens =
  let aux acc t =
    (token_to_string t) ^ ", " ^ acc
  in List.fold_left aux "" @@ List.rev tokens
