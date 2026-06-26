
```py
#define square proc ( x * x )
:square { x;
    x x *
} def 

:vec [ 69 420 1337 ] def

:grid [
    1 2 3;
    4 5 6
] def

:list ( vec grid "bar" true ) def

#prints grid with square applied to all cells
grid square print 
```

Yeah. My inferred Spall shape is:

## Spall

Spall is a tiny **PostScript-inspired stack language** for generative/cellular/grid work.

The core idea is:

```text
small stack language
+ proc values
+ dense homogeneous vec/grid values
+ whole-value cell-wise math
+ lightweight proc locals
```

So it is not “a normal language with weird syntax.” It is more like a little live-coding field language where a whole grid/image/simulation state is one value on the stack.

---

## Core execution

Everything executes left to right, pushing values and running words.

```spall
1 2 +
```

pushes `1`, pushes `2`, runs `+`, leaves `3`.

Words consume stack values and leave stack values.

```spall
256 256 grid noise blur norm draw
```

reads as:

```text
make grid
fill/generate noise
blur it
normalize it
draw it
```

---

## Names and definitions

Literal names use `:`.

```spall
:x
```

Bare names look up values.

```spall
x
```

Definitions use PostScript-ish `def`.

```spall
:x 10 def
```

means bind `x` to `10`.

Procedures are values too:

```spall
:square { x ;
    x x *
} def

5 square
```

So `def` is just a word that binds a name to a value. It is not a special declaration form.

---

## Delimiters

Current canon:

```text
{ ... }      proc / quoted code
[ ... ]      evaluated vec/grid collector
( ... )      evaluated list collector
# ...        line comment
```

Each delimiter has a separate job.

---

## Procedures

Raw stack proc:

```spall
{ dup * }
```

Named-input proc:

```spall
{ x ;
    x x *
}
```

Multi-input proc:

```spall
{ x y ;
    x x * y y * + sqrt
}
```

When the proc runs, inputs are popped from the stack into local names.

```spall
3 4 { x y ;
    x x * y y * + sqrt
} do
```

leaves `5`.

This gives you PostScript-style proc values, but avoids forcing every readable proc into `swap`, `over`, `rot` stack gymnastics.

---

## Vec and grid collectors

`[ ... ]` executes its contents and collects the values.

One row makes a `vec`:

```spall
[ 1 2 3 ]
```

Multiple rows separated by `;` make a `grid`:

```spall
[
    1 2 3;
    4 5 6;
    7 8 9
]
```

This is not a vec-of-vecs. It is a dense homogeneous rank-2 grid.

Because the collector executes, dynamic elements work naturally:

```spall
[ 1 2 + 4 5 * ]
```

produces:

```spall
[ 3 20 ]
```

That is one of the strongest parts of the design.

---

## Lists

`( ... )` is the general heterogeneous list collector.

```spall
:scene (
    ( "circle" [ 120 80 ] 40 red )
    ( "line" [ 0 0 ] [ 240 160 ] white )
) def
```

So the split is:

```text
[ ... ]    dense homogeneous numeric-ish vec/grid
( ... )    general heterogeneous list
```

---

## Types, as inferred

Likely initial value types:

```text
int
bool
string
proc
vec
grid
list
name
```

Maybe later:

```text
mask
color
shape
```

But for now, I’d think:

```text
vec     homogeneous rank-1 sequence
grid    homogeneous rank-2 cell field
list    heterogeneous collection
string  scalar text value, indexable
```

String indexing can return a one-character string if you do not want a separate `char` type.

```spall
"hello"[1]    # "e"
```

---

## Bool and masks

I’d infer this now:

```text
bool should exist as a real scalar kind.
comparisons on scalars return bool.
comparisons on grids return masks.
if requires scalar bool.
grid masks need where/any/all.
```

So:

```spall
3 4 >
```

returns `false`.

But:

```spall
field 0.5 >
```

returns a grid mask.

Then:

```spall
field 0.5 > white black where
```

selects cell-wise.

But this should be invalid:

```spall
field 0.5 > { ... } if
```

because that is a whole grid mask, not one scalar decision.

Use:

```spall
field 0.5 > any { "some bright cells" print } if
```

for scalar control.

---

## Indexing

Even though Spall is stack-based, postfix indexing can exist.

```spall
v[i]
g[x, y]
s[i]
```

These simply push the indexed value onto the stack.

Equivalent idea:

```spall
v i at
g x y at
```

But syntax is nicer.

---

## Minimal core words

Not generative words, just language substrate.

I’d infer the small core/prelude as:

```text
def
do

dup
drop
swap
over

if
ifelse
repeat
loop

=
!=
<
<=
>
>=

!
and
or

+
-
*
/
%

print
```

But `over` is not deeply required because proc locals reduce stack-shuffle pressure. It is just a conventional useful prelude word.

The truly important stack words are probably:

```text
dup
drop
swap
```

`over` is handy, but not central to Spall’s identity.

---

## Cell-wise arithmetic

This is the main power.

Scalar:

```spall
1 2 +
```

Vec:

```spall
[ 1 2 3 ] [ 10 20 30 ] +
```

produces:

```spall
[ 11 22 33 ]
```

Grid:

```spall
[
    1 2;
    3 4
]
10 *
```

produces:

```spall
[
    10 20;
    30 40
]
```

So arithmetic lifts over vecs/grids where shapes match or scalar broadcasting is allowed.

This is the real use case: short code that operates over many cells.

---

## Coordinate fields

Earlier `xgrid`/`ygrid` was better understood as `xcoords`/`ycoords`.

For a 4×3 shape:

```spall
4 3 xcoords
```

would produce:

```spall
[
    0 1 2 3;
    0 1 2 3;
    0 1 2 3
]
```

and:

```spall
4 3 ycoords
```

would produce:

```spall
[
    0 0 0 0;
    1 1 1 1;
    2 2 2 2
]
```

This lets users generate patterns from cell position.

Maybe better as one word:

```spall
256 256 coords
```

leaving:

```text
xcoords ycoords
```

Then:

```spall
256 256 coords + norm draw
```

makes a diagonal gradient.

---

## Example: simple generative field

```spall
:waves { w h ;
    w h xcoords 8 / sin
    w h ycoords 8 / cos
    +
    norm
} def

256 256 waves draw
```

This is the pitch: no explicit loops, but it fills a whole image/grid.

---

## Example: kernel/grid literal

```spall
:cross [
    0 1 0;
    1 1 1;
    0 1 0
] def

field cross convolve norm draw
```

This is where grid literals earn their keep.

---

## Example: Game of Life shape

```spall
:world 256 256 0.25 random-grid def

:life-step { live ;
    :n live neighbors8 def

    n 3 =
    live n 2 = and
    or
} def

:update {
    :world world life-step def
} def

:draw {
    world white black where draw
} def

:frame {
    update
    draw
} def

{ frame } loop
```

Because comparisons and boolean ops lift over grids/masks, the Life rule is written as a grid expression.

---

## What Spall is good for

The use case is not “because stack languages are cool.”

The use case is:

```text
generative art
cellular automata
small simulations
image/field processing
procedural textures
live coding
grid/mask experiments
```

The selling point is that whole grids are first-class values.

A normal implementation would need loops:

```c
for y:
    for x:
        img[x,y] = sin(x * 0.08) + cos(y * 0.08)
```

Spall can say:

```spall
256 256 xcoords 8 / sin
256 256 ycoords 8 / cos
+
norm
draw
```

It is esoteric, but it has a real lane.

---

## Current design feel

Spall is:

```text
PostScript-ish names/procs/def
Factor/Forth-ish stack flavor
array-language-ish cell-wise lifting
grid/cell/generative focus
```

The nicest summary is still:

```text
PostScript bones, numeric-grid soul.
```

It is coherent because the syntax pieces line up:

```text
:name value def      bind names
{ args ; body }      proc values with optional locals
[ ... ; ... ]        dense vec/grid values
( ... )              general list values
word word word       stack pipeline
```

That is already enough to write a small spec.
