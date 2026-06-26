# Spall
Spall is a cellular stack-based language inspired by PostScript, Forth, Factor, and APL. Vectors and Grids are first-class stack values. Numeric words are overloaded across scalars, vectors, and grids, so `grid grid +` adds matching cells and `grid 10 *` scales the whole grid.

See the [language reference](ref.md) for more details.

## Example

```py
# Define Proc as Name `greet`
:greet { name ;
    "Hello " . name . "!" print
}

# Invoke Word `greet` with a string
"Spall" greet

# Define Grid literal as Name `a`
:a [
    1 2 3;
    4 5 6
] def

# Define Grid literal as Name `b`
:b [
    10 20 30;
    40 50 60
] def

# Print a + b
a b + print
```

Prints:

```
Hello Spall!
11 22 33
44 55 66
```
