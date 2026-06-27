# Veld
Veld is a cellular stack-based language inspired by PostScript, Forth, Factor, and APL. Vectors and Grids are first-class stack values. Numeric words are overloaded across scalars, vectors, and grids, so `grid grid +` adds matching cells and `grid 10 *` scales the whole grid.

See the [language reference](ref.md) for more details.

## CLI

`eval` and `dump` take their source as exactly one shell argument.

```powershell
.\veld.exe eval '1 2 + print'
.\veld.exe eval '"hello veld!" print'
.\veld.exe dump '"hello veld!" print'
```

The outer single quotes are PowerShell quoting. The inner double quotes are Veld syntax and are
passed through to the language.

## Example

```py
# Define Proc as Name `greet`
:greet { name ;
    "Hello " . name . "!" print
}

# Invoke Word `greet` with a string
"Veld" greet

# Define Grid as Name `a`
:a [
    1 2 3;
    4 5 6
] def

# Define Grid as Name `b`
:b [
    10 20 30;
    40 50 60
] def

# Print a + b
a b + print
```

Prints:

```
Hello Veld!
11 22 33
44 55 66
```
