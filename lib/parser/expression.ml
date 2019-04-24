(* Parse the ocaml expression.                           *)
(* https://caml.inria.fr/pub/docs/manual-ocaml/expr.html *)

module L = Lexer
module Pat = Pattern
module Binop = Tree.Binop
module T = Tree.Expression

type t = Path.t T.t

(* fun x y z -> expr                      *)
(* => fun x -> (fun y -> (fun z -> expr)) *)
let rec params_to_lambdas expr = function
  | h :: t -> T.Lambda (h, params_to_lambdas expr t)
  | [] -> expr
;;

let rec parse_fun_params is_let = function
  | L.Arrow :: rest when not is_let -> rest, []
  | L.Equal :: rest when is_let -> rest, []
  | tokens ->
    let rest, pat = Pat.parse_pattern tokens in
    let rest, acc = parse_fun_params is_let rest in
    rest, pat :: acc
;;

let parse_let_fun_params = parse_fun_params true
let parse_lambda_fun_params = parse_fun_params false

let rec parse_match_arm tokens =
  let parse_from_arrow pat when_ = function
    | L.Arrow :: rest ->
      let rest, arm = parse_expression rest in
      (match rest with
      | L.Vertical :: rest ->
        let rest, acc = parse_match_arm rest in
        rest, (pat, when_, arm) :: acc
      | _ -> rest, [pat, when_, arm])
    | _ -> failwith "could not find '->'"
  in
  let rest, pat = Pat.parse_pattern tokens in
  match rest with
  | L.When :: rest ->
    let rest, when_ = parse_expression rest in
    parse_from_arrow pat (Some when_) rest
  | _ -> parse_from_arrow pat None rest

and parse_let_fun_body params = function
  | L.Function :: L.Vertical :: rest | L.Function :: rest ->
    let rest, arms = parse_match_arm rest in
    let anon_var = Path.single "_function_match" in
    rest, params @ [Tree.Pattern.Var anon_var], T.Match (T.Var anon_var, arms)
  | rest ->
    let rest, body = parse_expression rest in
    rest, params, body

and parse_let_bindings rest =
  let rec parse_until_in rest =
    let rest, bind = Pat.parse_pattern rest in
    let rest, params = parse_let_fun_params rest in
    let rest, params, lhs = parse_let_fun_body params rest in
    match rest with
    | L.And :: rest ->
      let rest, acc = parse_until_in rest in
      rest, (bind, params, lhs) :: acc
    | rest -> rest, [bind, params, lhs]
  and conv_params (bind, params, lhs) =
    match params with
    | h :: t ->
      (match bind with
      | Tree.Pattern.Var ident -> T.FunBind (ident, h, params_to_lambdas lhs t)
      | _ -> failwith "only variables are allowed to bind functions")
    | [] -> T.VarBind (bind, lhs)
  in
  let rest, acc = parse_until_in rest in
  rest, List.map conv_params acc

and parse_rec = function L.Rec :: rest -> rest, true | tokens -> tokens, false

and parse_in = function
  | L.In :: rest -> parse_expression rest
  | _ -> failwith "could not find `in`"

and parse_fields tokens =
  let continue path expr = function
    | L.Semicolon :: rest ->
      let rest, acc = parse_fields rest in
      rest, (path, expr) :: acc
    | rest -> rest, [path, expr]
  in
  let rest, path = Path.parse_path tokens in
  match rest with
  | L.Equal :: rest ->
    let rest, expr = parse_let rest in
    continue path expr rest
  | rest when Path.is_empty path -> rest, []
  | rest -> continue path (T.Var (Path.last_path path)) rest

and parse_record tokens =
  let parse_value tokens =
    let rest, fields = parse_fields tokens in
    rest, T.Record fields
  and try_parse_with tokens =
    let rest, expr = parse_let tokens in
    match rest with
    | L.With :: rest ->
      let rest, fields = parse_fields rest in
      rest, Some (T.RecordUpdate (expr, fields))
    | _ -> tokens, None
  in
  let aux tokens =
    let rest, v_opt = try_parse_with tokens in
    match v_opt with Some v -> rest, v | None -> parse_value tokens
  in
  let rest, v = match tokens with L.LBrace :: rest | rest -> aux rest in
  match rest with L.RBrace :: rest -> rest, v | _ -> failwith "could not find `}`"

and try_parse_literal tokens =
  match tokens with
  | L.IntLiteral num :: tokens -> tokens, Some (T.Int num)
  (* TODO: Add boolean value *)
  | L.BoolLiteral b :: tokens -> tokens, Some (T.Int (if b then 1 else 0))
  (* TODO: Add char value *)
  | L.CharLiteral c :: tokens -> tokens, Some (T.Int (Char.code c))
  | L.StringLiteral s :: tokens -> tokens, Some (T.String s)
  | L.LowerIdent ident :: rest -> rest, Some (T.Var (Path.single ident))
  | L.CapitalIdent _ :: _ ->
    (match Path.parse_path tokens with
    | rest, Path [] -> rest, None
    | rest, path when Path.is_capitalized path ->
      (match try_parse_literal rest with
      | rest, Some p -> rest, Some (T.Ctor (path, Some p))
      | _, None -> rest, Some (T.Ctor (path, None)))
    | rest, path -> rest, Some (T.Var path))
  | L.LBrace :: rest ->
    let rest, r = parse_record rest in
    rest, Some r
  | L.LBracket :: rest ->
    let rec aux = function
      | L.RBracket :: rest -> rest, T.Nil
      | L.Semicolon :: rest -> aux rest
      | tokens ->
        let rest, lhs = parse_let tokens in
        let rest, rhs = aux rest in
        rest, T.BinOp (Binop.Cons, lhs, rhs)
    in
    let rest, l = aux rest in
    rest, Some l
  | L.LParen :: tokens ->
    let rest, v = parse_expression tokens in
    (match rest with L.RParen :: rest -> rest, Some v | _ -> rest, None)
  | _ -> tokens, None

and try_parse_dot tokens =
  let rest, lhs_opt = try_parse_literal tokens in
  match lhs_opt with
  | Some lhs ->
    (match rest with
    | L.Dot :: L.LowerIdent ident :: rest -> rest, Some (T.RecordField (lhs, ident))
    | L.Dot :: L.LBracket :: rest ->
      let rest, rhs = parse_expression rest in
      (match rest with
      | L.RBracket :: rest -> rest, Some (T.BinOp (Binop.StringIndex, lhs, rhs))
      | _ -> tokens, None)
    | _ -> rest, Some lhs)
  | None -> tokens, None

and parse_dot tokens =
  match try_parse_dot tokens with
  | tokens, Some v -> tokens, v
  | h :: _, None ->
    failwith @@ Printf.sprintf "unexpected token: '%s'" (L.string_of_token h)
  | [], None -> failwith "Empty input"

and parse_app tokens =
  let rest, f = parse_dot tokens in
  let rec aux lhs tokens =
    match try_parse_dot tokens with
    | rest, Some p -> aux (T.App (lhs, p)) rest
    | rest, None -> rest, lhs
  in
  aux f rest

and parse_mult tokens =
  let tokens, lhs = parse_app tokens in
  let rec aux lhs tokens =
    match tokens with
    | L.Star :: rest ->
      let rest, rhs = parse_app rest in
      aux (T.BinOp (Binop.Mul, lhs, rhs)) rest
    | _ -> tokens, lhs
  in
  aux lhs tokens

and parse_add tokens =
  let tokens, lhs = parse_mult tokens in
  let rec aux lhs tokens =
    match tokens with
    | L.Plus :: rest ->
      let rest, rhs = parse_mult rest in
      aux (T.BinOp (Binop.Add, lhs, rhs)) rest
    | L.Minus :: rest ->
      let rest, rhs = parse_mult rest in
      aux (T.BinOp (Binop.Sub, lhs, rhs)) rest
    | _ -> tokens, lhs
  in
  aux lhs tokens

and parse_cons tokens =
  let tokens, lhs = parse_add tokens in
  match tokens with
  | L.DoubleColon :: tokens ->
    let tokens, rhs = parse_cons tokens in
    tokens, T.BinOp (Binop.Cons, lhs, rhs)
  | _ -> tokens, lhs

and parse_append tokens =
  let tokens, lhs = parse_cons tokens in
  let rec aux lhs tokens =
    match tokens with
    | L.Hat :: rest ->
      let rest, rhs = parse_cons rest in
      aux (T.BinOp (Binop.StringAppend, lhs, rhs)) rest
    | _ -> tokens, lhs
  in
  aux lhs tokens

and parse_equal tokens =
  let tokens, lhs = parse_append tokens in
  let rec aux lhs tokens =
    match tokens with
    | L.Equal :: rest ->
      let rest, rhs = parse_append rest in
      aux (T.BinOp (Binop.Equal, lhs, rhs)) rest
    | L.DoubleEqual :: rest ->
      let rest, rhs = parse_append rest in
      aux (T.BinOp (Binop.PhysicalEqual, lhs, rhs)) rest
    | L.LtGt :: rest ->
      let rest, rhs = parse_append rest in
      aux (T.BinOp (Binop.NotEqual, lhs, rhs)) rest
    | L.NotEqual :: rest ->
      let rest, rhs = parse_append rest in
      aux (T.BinOp (Binop.NotPhysicalEqual, lhs, rhs)) rest
    | _ -> tokens, lhs
  in
  aux lhs tokens

and parse_tuple tokens =
  let rec aux tokens =
    let rest, curr = parse_equal tokens in
    match rest with
    | L.Comma :: rest ->
      let rest, tail = aux rest in
      rest, curr :: tail
    | _ -> rest, [curr]
  in
  let rest, values = aux tokens in
  match values with
  | [] -> failwith "unreachable"
  | [value] -> rest, value
  | _ -> rest, T.Tuple values

and parse_if = function
  | L.If :: rest ->
    let rest, cond = parse_expression rest in
    (match rest with
    | L.Then :: rest ->
      let rest, then_ = parse_expression rest in
      (match rest with
      | L.Else :: rest ->
        let rest, else_ = parse_expression rest in
        rest, T.IfThenElse (cond, then_, else_)
      | _ -> failwith "could not find 'else'")
    | _ -> failwith "could not find 'then'")
  | tokens -> parse_tuple tokens

and parse_match = function
  | L.Match :: rest ->
    let rest, expr = parse_expression rest in
    (match rest with
    | L.With :: L.Vertical :: rest | L.With :: rest ->
      let rest, arms = parse_match_arm rest in
      rest, T.Match (expr, arms)
    | _ -> failwith "could not find 'with'")
  | tokens -> parse_if tokens

and parse_let = function
  | L.Fun :: rest ->
    let rest, params = parse_lambda_fun_params rest in
    let rest, params, body = parse_let_fun_body params rest in
    rest, params_to_lambdas body params
  | L.Let :: rest ->
    let rest, is_rec = parse_rec rest in
    let rest, binds = parse_let_bindings rest in
    let rest, rhs = parse_in rest in
    rest, T.LetAnd (is_rec, binds, rhs)
  | tokens -> parse_match tokens

and parse_follow tokens =
  let tokens, lhs = parse_let tokens in
  let rec aux lhs tokens =
    match tokens with
    | L.Semicolon :: rest ->
      let rest, rhs = parse_let rest in
      aux (T.BinOp (Binop.Follow, lhs, rhs)) rest
    | _ -> tokens, lhs
  in
  aux lhs tokens

and parse_expression tokens = parse_follow tokens

<<<<<<< HEAD
let rec string_of_let_binding = function
  | VarBind (pat, expr) ->
    Printf.sprintf "(%s) = (%s)" (Pat.string_of_pattern pat) (string_of_expression expr)
  | FunBind (ident, param, expr) ->
    Printf.sprintf
      "%s (%s) = (%s)"
      (Path.string_of_path ident)
      (Pat.string_of_pattern param)
      (string_of_expression expr)

and string_of_expression = function
  | Int num -> Printf.sprintf "Int %d" num
  | Tuple values ->
    let p = List.map string_of_expression values |> String.concat ", " in
    Printf.sprintf "Tuple (%s)" p
  | String s -> Printf.sprintf "String \"%s\"" s
  | Add (lhs, rhs) ->
    Printf.sprintf "Add (%s) (%s)" (string_of_expression lhs) (string_of_expression rhs)
  | Sub (lhs, rhs) ->
    Printf.sprintf "Sub (%s) (%s)" (string_of_expression lhs) (string_of_expression rhs)
  | Mul (lhs, rhs) ->
    Printf.sprintf "Mul (%s) (%s)" (string_of_expression lhs) (string_of_expression rhs)
  | Follow (lhs, rhs) ->
    Printf.sprintf "(%s); (%s)" (string_of_expression lhs) (string_of_expression rhs)
  | Equal (lhs, rhs) ->
    Printf.sprintf
      "Equal (%s) (%s)"
      (string_of_expression lhs)
      (string_of_expression rhs)
  | NotEqual (lhs, rhs) ->
    Printf.sprintf
      "NotEqual (%s) (%s)"
      (string_of_expression lhs)
      (string_of_expression rhs)
  | PhysicalEqual (lhs, rhs) ->
    Printf.sprintf
      "PhysicalEqual (%s) (%s)"
      (string_of_expression lhs)
      (string_of_expression rhs)
  | NotPhysicalEqual (lhs, rhs) ->
    Printf.sprintf
      "NotPhysicalEqual (%s) (%s)"
      (string_of_expression lhs)
      (string_of_expression rhs)
  | LetAnd (is_rec, l, rhs) ->
    let l = List.map string_of_let_binding l |> String.concat " and " in
    Printf.sprintf
      "Let %s %s in (%s)"
      (if is_rec then "rec" else "")
      l
      (string_of_expression rhs)
  | App (lhs, rhs) ->
    Printf.sprintf "App (%s) (%s)" (string_of_expression lhs) (string_of_expression rhs)
  | Ctor (path, rhs) ->
    let name = Path.string_of_path path in
    (match rhs with
    | Some rhs -> Printf.sprintf "Ctor (%s) (%s)" name (string_of_expression rhs)
    | None -> Printf.sprintf "Ctor (%s)" name)
  | IfThenElse (cond, then_, else_) ->
    Printf.sprintf
      "If (%s) then (%s) else (%s)"
      (string_of_expression cond)
      (string_of_expression then_)
      (string_of_expression else_)
  | Var path -> Printf.sprintf "Var %s" @@ Path.string_of_path path
  | Match (expr, arms) ->
    let string_of_when = function
      | Some w -> Printf.sprintf "when (%s)" (string_of_expression w)
      | None -> ""
    in
    let string_of_arm (pat, when_, arm) =
      Printf.sprintf
        "(%s) %s -> (%s)"
        (Pat.string_of_pattern pat)
        (string_of_when when_)
        (string_of_expression arm)
    in
    let p = List.map string_of_arm arms |> String.concat " | " in
    Printf.sprintf "Match (%s) with %s" (string_of_expression expr) p
  | Lambda (param, body) ->
    let p = Pat.string_of_pattern param in
    Printf.sprintf "(%s) -> (%s)" p (string_of_expression body)
  | Cons (lhs, rhs) ->
    Printf.sprintf "Cons (%s) (%s)" (string_of_expression lhs) (string_of_expression rhs)
  | Nil -> "Nil"
  | StringIndex (lhs, rhs) ->
    Printf.sprintf
      "StringIndex (%s) (%s)"
      (string_of_expression lhs)
      (string_of_expression rhs)
  | StringAppend (lhs, rhs) ->
    Printf.sprintf
      "StringAppend (%s) (%s)"
      (string_of_expression lhs)
      (string_of_expression rhs)
  | Record fields ->
    let aux (path, expr) =
      Printf.sprintf "%s = (%s)" (Path.string_of_path path) (string_of_expression expr)
    in
    List.map aux fields |> String.concat "; " |> Printf.sprintf "{%s}"
  | RecordField (v, field) ->
    Printf.sprintf "RecordField (%s).%s" (string_of_expression v) field
  | RecordUpdate (e, fields) ->
    let aux (path, expr) =
      Printf.sprintf "%s = (%s)" (Path.string_of_path path) (string_of_expression expr)
    in
    List.map aux fields
    |> String.concat "; "
    |> Printf.sprintf "{%s with %s}" (string_of_expression e)
;;

let f = parse_expression
