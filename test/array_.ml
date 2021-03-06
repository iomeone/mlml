let () =
  Tester.f {|
let ary = [|1; 2; 3|] in
print_int ary.(1)
  |};
  Tester.f {|
let a = [|1; 2; 3|] in
let [|x; y; z|] = a in
print_int (x * y + z)
  |};
  Tester.f
    {|
let a = [| [| 1; 2 |]; [| 3; 4 |] |] in
let [| a; [| b; c |] |] = a in
print_int (b + c);
print_int a.(0)
  |};
  Tester.f
    {|
let a = [| 1; 2; 3; 4 |] in
print_int a.(2);
a.(2) <- 10;
print_int a.(2)
  |};
  Tester.f
    {|
let a = [| "a"; "b"; "c" |] in
let b = a in
a.(2) <- "d";
print_string b.(2)
  |};
  Tester.f
    {|
let f = function
  | [| a |] -> print_int a
  | [| a; b |] -> print_int (a * b)
  | _ -> print_int 1200
;;

f [| 2; 13 |];
f [| 3 |];
f [| 3; 243; 234 |]
  |};
  (* Library features *)
  Tester.f {|
let a = [| 3; 2; 5 |] in
print_int @@ Array.length a
  |};
  Tester.f
    {|
let a = Array.make 10 "hello" in
print_int @@ Array.length a;
let print_array a =
  let rec aux i =
    print_string @@ Array.get a i;
    if i != 0 then aux (i - 1)
  in aux (Array.length a - 1)
in
print_array a
  |};
  Tester.f {|
Array.to_list [|1; 2; 3|] |> List.iter print_int
  |};
  Tester.f {|
let f acc i = acc * (i + 5) in
Array.fold_left f 0 [|1; 2; 3; 4; 5|]
  |}
;;
