Yeah. The reason fixed-arity stack words are normal is **not** because the deep stack is useless. It is because deep stack state is *context*, not an implicit argument list.

A stack word with a declared/fixed effect is composable:

```text
cat   ( a b -- c )
+     ( a b -- c )
dup   ( a -- a a )
print ( x -- )
```

You can locally reason about it. It only depends on the top values it says it consumes.

A whole-stack word like:

```text
cat-all ( ... -- string )
```

depends on everything that happened before it. That is sometimes useful for debug/session words, but dangerous for normal program words because leftover stack values become accidental inputs. Factor’s tutorial says this explicitly in its own way: stack functions can only directly see the top of the stack, deeper values are effectively out of scope unless you manipulate them, and excessive stack shuffling quickly makes code harder to read/write. ([andreaferretti.github.io][1])

So the rule is:

```text
normal computation words: fixed stack effect
debug/session words: may inspect/clear/show whole stack
collectors/lists: explicit boundary for variable arity
```

That last one is the key. Variable arity is fine when there is an explicit boundary:

```veld
[ "Hello " name "!" ] concat print
```

Here `concat` is not eating ambient stack. It consumes one collection value.

## Is Veld `join` like Factor `join`?

Roughly, yes, **if** Veld has an explicit sequence/list value.

Factor’s own homepage has an example using `split`, `flip`, and then `[ "|" join ] map`, where `join` joins sequence elements using `"|"` as the separator. ([factorcode.org][2])

So Factor-ish semantics are more like:

```text
join   ( sequence separator -- sequence/string )
```

or in Veld-ish prose:

```veld
[ "a" "b" "c" ] ", " join print
```

Output:

```text
a, b, c
```

That is **not** the same as “join the whole current stack.”

## Is `concat` closer to what you want?

Yes. For string composition with no separator, `concat` is the closer name:

```veld
[ "Hello " name "!" ] concat print
```

Meaning:

```text
concat ( list -- string )
```

That says: collapse this explicit list/collector of pieces into one string.

So the later naming split I’d keep is:

```text
cat     ( a b -- c )          binary concatenate
concat  ( list -- string )    concatenate all pieces, no separator
join    ( list sep -- string) concatenate pieces with separator
```

For your original `"Hello " name "!"` case, the best later shape is probably:

```veld
[ "Hello " name "!" ] concat print
```

not `join`, unless you actually want a separator.

So yes: **Factor `concat` is closer to your no-separator string builder. Factor `join` is separator-based sequence joining.**

[1]: https://andreaferretti.github.io/factor-tutorial/ "Factor tutorial by andreaferretti"
[2]: https://factorcode.org/ "Factor programming language"
