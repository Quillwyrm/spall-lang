# Spall Reference

Spall is a small PostScript-inspired stack language for generative grid, cell, and field work.

Its core idea is:

```text
stack execution
+ first-class procs
+ dense vec/grid values
+ cell-wise lifted math
+ small persistent definitions
```

A Spall program is a sequence of values and words. Values are pushed onto the stack. Words consume stack values and may push results.

```py
1 2 +
```

Pushes `1`, pushes `2`, runs `+`, and leaves `3`.

---

## 1. Comments

`#` starts a line comment.

```py
# define square proc
:square { x ;
    x x *
} def
```

The usual style is one space after `#`.

---

## 2. Tokens and words

Spall is whitespace-tokenized.

```py
x y +
```

is three tokens.

Kebab-case names are allowed:

```py
random-grid
count-true
in-bounds
```

`x-y` is one word name. To subtract, use spaces:

```py
x y -
```

Structural delimiters also separate tokens:

```py
[ 1 2 3 ]
{ x ; x x * }
( "foo" true )
```

---

## 3. Values

Core value kinds:

```text
int
float
bool
string
name
proc
vec
grid
list
```

There is no `nil` / `null` in core Spall.

Missing names, stack underflow, wrong types, out-of-bounds indexing, bad grid shapes, and similar invalid operations are hard execution errors.

---

## 4. Numbers

Integer literals:

```py
1
42
-7
```

Float literals:

```py
1.0
1.
.5
-0.25
```

Spall has separate `int` and `float` numeric values.

Arithmetic words work on numbers. Mixed numeric operations may promote to float when needed.

```py
1 2 /     # 0.5
```

Modulo is spelled `mod`.

```py
7 3 mod
```

---

## 5. Booleans

Booleans are real values:

```py
true
false
```

Comparisons return booleans.

```py
3 4 <     # true
```

Control flow requires booleans. Spall does not use general truthiness.

```py
true { "yes" print } if
```

This is invalid:

```py
1 { "yes" print } if
```

---

## 6. Names and lookup

A bare name looks up a value.

```py
x
```

A colon-prefixed name pushes a literal name value.

```py
:x
```

Names are used by definition words such as `def`.

---

## 7. Definitions

`def` creates or updates a persistent definition.

```py
:x 10 def
```

Stack effect:

```text
name value -- 
```

So this defines `x` as `10`.

```py
:x 10 def
x print
```

Definitions live in the global definition dictionary.

Calling `def` again updates the definition:

```py
:x 10 def
:x 20 def

x print  # 20
```

Inside a proc, `def` still creates or updates the global definition dictionary.

```py
:x 10 def

:update-x {
    :x 20 def
} def

update-x
x print  # 20
```

---

## 8. Procedures

A proc is quoted executable code.

```py
{ 1 2 + }
```

A proc value can be executed with `do`.

```py
{ 1 2 + } do
```

Leaves `3`.

When a bare name resolves to a proc, the proc auto-executes.

```py
:say-hi {
    "hi" print
} def

say-hi
```

---

## 9. Proc input locals

A proc may declare input locals before a `;`.

```py
{ x ;
    x x *
}
```

When called, the proc pops one value and binds it to `x` for that call.

```py
:square { x ;
    x x *
} def

5 square  # 25
```

Multiple input locals are bound left to right from the stack.

```py
:dist { x y ;
    x x *
    y y *
    +
    sqrt
} def

3 4 dist  # 5
```

For `3 4 dist`, `x = 3` and `y = 4`.

Proc input locals are not ordinary definitions. They are temporary input aliases for the current proc call.

Lookup inside a proc checks:

```text
1. proc input locals
2. global definitions
```

So locals shadow globals while the proc runs.

```py
:x 10 def

:test { x ;
    x print
} def

5 test  # 5
```

`def` does not create or mutate proc input locals.

```py
:x 10 def

:test { x ;
    :x 20 def
    x print
} def

5 test
x print
```

prints:

```text
5
20
```

Inside the proc, `x` resolves to the input local. The `def` updates the global `x`.

A proc with no input locals has no `;`.

```py
:hello {
    "hello" print
} def
```

This form is invalid:

```py
{ ;
    "hello" print
}
```

---

## 10. Vecs and grids

`[ ... ]` executes its contents and collects the values produced inside the collector.

A single row creates a `vec`.

```py
[ 1 2 3 ]
```

Semicolon-separated rows create a `grid`.

```py
[
    1 2 3;
    4 5 6
]
```

All grid rows must have the same width.

Spall’s core grid lane is homogeneous. Numeric vecs/grids are the main required form.

```py
:vec [ 69 420 1337 ] def

:grid [
    1 2 3;
    4 5 6
] def
```

Collectors execute code, so this:

```py
[ 1 2 + 4 5 * ]
```

produces:

```py
[ 3 20 ]
```

---

## 11. Lists

`( ... )` executes its contents and collects heterogeneous values into a list.

```py
:list ( vec grid "bar" true ) def
```

Lists may contain mixed value kinds.

```py
( 1 "foo" true [ 1 2 3 ] )
```

---

## 12. Strings

Core strings are ASCII strings.

```py
"hello"
```

String indexing returns a one-character string.

```py
"hello"[1]  # "e"
```

String `count` returns the number of characters.

```py
"hello" count  # 5
```

---

## 13. Indexing

Postfix indexing reads from vecs, grids, strings, and lists.

```py
vec[i]
grid[x, y]
string[i]
list[i]
```

Examples:

```py
[ 10 20 30 ][1]  # 20

:grid [
    1 2 3;
    4 5 6
] def

grid[1, 0]       # 2
"hello"[1]       # "e"
```

Indexing is read-only in core Spall.

Out-of-bounds indexing is an error.

---

## 14. Count and shape

`count` returns the number of contained items.

```py
[ 1 2 3 ] count       # 3
( "a" "b" true ) count # 3
"hello" count         # 5
```

For grids, `count` returns total cell count.

```py
:grid [
    1 2 3;
    4 5 6
] def

grid count   # 6
grid width   # 3
grid height  # 2
grid shape   # grid shape value
```

`width`, `height`, and `shape` are grid-specific.

---

## 15. Arithmetic and lifting

Arithmetic works on scalar numbers.

```py
1 2 +
5 3 -
4 2 *
8 2 /
```

Builtin numeric operations lift over vecs and grids.

```py
[ 1 2 3 ] [ 10 20 30 ] +
```

produces:

```py
[ 11 22 33 ]
```

Grid operations are cell-wise.

```py
[
    1 2 3;
    4 5 6
]
10 *
```

produces:

```py
[
    10 20 30;
    40 50 60
]
```

Scalars broadcast over vecs and grids.

```py
grid 0.5 *
```

User-defined procs are not automatically mapped. They work over grids because the words they use may lift.

```py
:square { x ;
    x x *
} def

5 square
grid square
```

The proc receives one value either way. If that value is a grid, `*` performs grid multiplication.

---

## 16. Control flow

Control flow words consume proc values.

### if

```py
condition { body } if
```

Example:

```py
3 4 < {
    "yes" print
} if
```

### ifelse

```py
condition { then-body } { else-body } ifelse
```

Example:

```py
3 4 < {
    "less" print
} {
    "not less" print
} ifelse
```

### repeat

```py
count { body } repeat
```

Runs the proc `count` times.

```py
3 {
    "tick" print
} repeat
```

### loop

```py
{ body } loop
```

Runs the proc repeatedly until `exit`.

```py
{
    "tick" print
    exit
} loop
```

`exit` leaves the nearest active `loop` or `repeat`.

---

## 17. Errors

Spall uses simple hard execution errors.

Examples:

```text
unknown name
stack underflow
wrong type
shape mismatch
out-of-bounds index
bad grid row width
invalid control condition
```

There is no core language-level recovery system.

A host REPL may catch an error, report it, and accept more input, but that is outside core Spall semantics.

---

## 18. Example

```py
# define square proc
:square { x ;
    x x *
} def

:vec [ 69 420 1337 ] def

:grid [
    1 2 3;
    4 5 6
] def

:list ( vec grid "bar" true ) def

# print grid with square applied to all cells
grid square print
```

This prints a grid equivalent to:

```py
[
    1 4 9;
    16 25 36
]
```

`square` is written once. It works on a scalar or a grid because `*` lifts over grids.

---

## 19. Example: grid addition

```py
:a [
    1 2 3;
    4 5 6
] def

:b [
    10 20 30;
    40 50 60
] def

a b + print
```

Prints:

```py
[
    11 22 33;
    44 55 66
]
```

Whole grids are values, and arithmetic operates over their cells.
