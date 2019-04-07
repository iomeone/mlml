# mlml

mlml is a tiny ML subset written in OCaml.

This compiler takes a source string as input, and produces x86\_64 assembly.

## roadmap

- [x] basic arithmetic
  - [ ] div, shift, non-equality comparison, etc
- [x] variables
- [x] if-then-else
- [x] functions
  - [x] recursion
  - [ ] lambda
  - [ ] closure
  - [ ] currying
- [x] tuples
  - [x] pattern matching
- [ ] new type definition
  - [ ] pattern matching
- [ ] pattern matching with `match`
- [ ] type checker & type inference
- [ ] ... and more ...
- [ ] **self-hosting!**

## thanks

The code and algorithm in parser and lexer is strongly inspired by [ushitora-anqou/aqaml](https://github.com/ushitora-anqou/aqaml)