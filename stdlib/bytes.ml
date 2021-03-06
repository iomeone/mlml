external of_string : string -> bytes = "_mlml_shallow_copy"
external to_string : bytes -> string = "_mlml_shallow_copy"
external copy : bytes -> bytes = "_mlml_shallow_copy"
external create : int -> bytes = "_mlml_create_string"
external length : bytes -> int = "_mlml_length_string"
external _get : bytes * int -> char = "_mlml_get_string"
external _set : bytes * int * char -> unit = "_mlml_set_string"

let get s n = _get (s, n)
let set s n c = _set (s, n, c)
let empty = create 0

let blit src srcoff dst dstoff len =
  let rec aux i =
    let srcidx = srcoff + i in
    let dstidx = dstoff + i in
    set dst dstidx @@ get src srcidx;
    if i != 0 then aux (i - 1)
  in
  match len with 0 -> () | len -> aux (len - 1)
;;

let blit_string src srcoff dst dstoff len = blit src srcoff dst dstoff len |> to_string

let sub s start len =
  let b = create len in
  blit s start b 0 len;
  b
;;

let sub_string s start len = sub s start len |> to_string

let init n f =
  let b = create n in
  let rec aux i =
    set b i (f i);
    if i != 0 then aux (i - 1)
  in
  (match n with 0 -> () | n -> aux (n - 1));
  b
;;

let make n c = init n (fun _ -> c)
