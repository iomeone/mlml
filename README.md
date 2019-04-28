# mlml

[![Build Status](https://travis-ci.com/coord-e/mlml.svg?branch=develop)](https://travis-ci.com/coord-e/mlml)
[![Coverage Status](https://coveralls.io/repos/github/coord-e/mlml/badge.svg)](https://coveralls.io/github/coord-e/mlml)
![Docker Cloud Automated build](https://img.shields.io/docker/cloud/automated/coorde/mlml.svg)
![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/coorde/mlml.svg)
[![MicroBadger Image](https://images.microbadger.com/badges/image/coorde/mlml.svg)](https://microbadger.com/images/coorde/mlml)

mlml is a tiny ML subset written in OCaml.

This compiler takes a source string as input, and produces x86\_64 assembly.

## roadmap

- [x] basic arithmetic
  - [ ] div, shift, etc
- [x] variables
- [x] if-then-else
- [x] functions
  - [x] recursion
  - [x] mutual recursion
  - [x] closure
  - [x] currying
- [x] tuples
- [x] variants
- [x] records
- [x] pattern matching with `match`
- [x] structual comparison
- [ ] primitive types
  - [x] string
  - [x] list
  - [ ] bytes
- [ ] modules
  - [x] definition
  - [x] aliases
  - [x] `open`
  - [ ] importing from other files
- [ ] type checker & type inference
- [ ] ... and more ...
- [ ] **self-hosting!**

## thanks

The code and algorithm in parser and lexer is strongly inspired by [ushitora-anqou/aqaml](https://github.com/ushitora-anqou/aqaml)
