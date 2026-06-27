# Odin Agents Bible

This file is a cheat sheet and rulebook for working on this project in Odin.

Its job is to stop LLMs from guessing Odin syntax, importing habits from other
languages, and adding code cruft because they do not know the language surface.


## Sources Checked

- Local Odin root: `C:\code\tools\Odin`
- Local Odin version checked with `odin version`: `dev-2026-03-nightly:6d9a611`
- Official overview docs: `https://odin-lang.org/docs/overview/`
- Syntax probe checked with `odin check <dir> -no-entry-point`

If a rule below conflicts with the current compiler, check the current Odin docs
and a tiny probe before changing project code.


## Domain Lock

When answering Odin questions:

- Use official Odin syntax.
- Use documented core library calls.
- Do not infer from C, Go, Zig, Jai, C++, Lua, Rust, or Python.
- If unsure, say `Unknown in Odin` and check.
- If the project already has nearby Odin code, inspect that code first.
- If the language surface is still uncertain, make a tiny probe and run
  `odin check <dir> -no-entry-point`.

Do not produce Odin-shaped pseudocode and call it Odin.


## The Specific Mistake

This is valid Odin:

```odin
generator_state := struct {
    name:             string,
    param_count:      int,
    bytecode:         [dynamic]u32,
    const_pool:       [dynamic]vm.Value,
    frame_slot_count: int,
}{}
```

The claim that this needs a named type was wrong.

Use a named type when the type itself matters:

- multiple values share the type
- the type appears in proc signatures
- the type is part of the public API
- the type has real domain meaning

For a single private package-state record, anonymous struct state via `:=` is
valid and can be the clearer shape.


## `:=` And `::`

Core rule:

```odin
x := 123
```

Declares a variable and infers the type from the value.

```odin
X :: 123
```

Declares a constant entity.

```odin
Thing :: struct {
    count: int,
}
```

Declares a named type.

```odin
run :: proc() {
}
```

Declares a procedure entity.

Do not confuse `::` and `:=`. That distinction is core Odin knowledge.


## Packages And Imports

Odin thinks in directory packages.

A package is a directory of `.odin` files with the same `package` declaration.
All files in that directory belong to the same package.

Core import:

```odin
import "core:fmt"
```

Alias import:

```odin
import gen "codegen"
```

Do not invent file-level imports. Import packages, not individual Odin files.

Current project shape:

```txt
src/
    main.odin            package main
    kiln/
        vm.odin          package kiln
        scanner.odin     package kiln
        parser.odin      package kiln
        codegen.odin     package kiln
        builtins.odin    package kiln
        error.odin       package kiln
        runtime.odin     package kiln
```

Dependency direction:

```txt
main -> kiln
```

Everything is a single `package kiln`. Cross-module naming (e.g. `proto_state` vs `parser_state`) keeps concerns distinct within the package.


## Slices, Arrays, Dynamic Arrays

Fixed array:

```odin
items := [?]int{10, 20, 30}
```

`[?]int` means infer the fixed array length from the literal.

Slice:

```odin
items_slice: []int
```

`[]T` is a slice. A slice is a view over contiguous elements. It has pointer
and length information. It does not own growth behavior.

Full slice shorthand:

```odin
items[:]
```

`[:]` means take a view of the whole array or dynamic array.

Dynamic array:

```odin
items := make([dynamic]int)
append(&items, 10)
append(&items, 20)
```

`[dynamic]T` is growable. It tracks length, capacity, allocator-backed storage.

Make with capacity:

```odin
items := make([dynamic]int, 0, 16)
```

Length starts at `0`. Capacity starts at `16`.

Reserve:

```odin
reserve(&items, 32)
```

This reserves backing capacity. It does not increase length.

Project rule:

- VM proto fields use slices when the VM only needs to read finalized data.
- Codegen state can use dynamic arrays while building.
- Finish converts dynamic arrays to slices with `[:]`.


## `append`

Official docs show bare append:

```odin
x: [dynamic]int
append(&x, 123)
append(&x, 4, 1, 74, 3)
```

Appending a slice uses `..`:

```odin
y: [dynamic]int
append(&y, ..x[:])
```

Local Odin core also uses bare `append(&array, value)` in normal code.

Do not add append error handling by default:

```odin
_, append_error := append(&items, value)
if append_error != nil {
    panic("failed to append")
}
```

That is accidental complexity unless this call site is actually designed around
allocator errors.

Use `or_return` or explicit error handling only when the surrounding proc has a
real error contract and allocation failure is part of that contract.

Project default:

```odin
append(&generator_state.bytecode, u32(vm.InstABx{
    op = .LOAD_CONST,
    a  = u8(dst),
    b  = u16(const_index),
}))
```


## Variadic Parameters

This is valid Odin:

```odin
record_slots :: proc(slots: ..int) {
    for slot in slots {
        needed_slot_count := slot + 1
        if needed_slot_count > generator_state.frame_slot_count {
            generator_state.frame_slot_count = needed_slot_count
        }
    }
}
```

Call it like:

```odin
record_slots(dst, lhs, rhs)
record_slots(dst)
```

Use this only when it centralizes a real invariant. For bytecode generation,
recording the maximum touched register slot is a real invariant, so this helper
can earn its cost.

Do not use variadics to hide arbitrary unrelated work.


## Procedures And Declaration Order

Odin package declarations are not C-style forward-declaration driven.

Even when Odin allows calling a proc declared later in the file, project style
still matters.

House style:

- public/core surface first
- then current operation groups
- internals at the bottom only when that does not make reading worse
- do not use declaration order as an excuse for tangled code

If an internal helper is called everywhere and defines an invariant, it can live
near the top of the relevant section. Do not bury it just to satisfy a fake
"internals at bottom" habit.


## Unions And Type Assertions

Current VM value:

```odin
Value :: union {
    bool,
    i64,
    f64,
    ^Object,
}
```

The zero value of this union represents Kiln nil in this project.

Type assertion:

```odin
int_value, is_int := value.(i64)
if is_int {
    // int_value is the i64 payload
}
```

Project style prefers named condition flags:

```odin
left_int, is_int := lhs.(i64)
```

Avoid generic `ok` when a clearer condition name costs nothing:

```odin
left_int, ok := lhs.(i64) // avoid in Kiln style
```

Avoid compact clever type switches in this project when expanded assertions read
more directly:

```odin
switch value_payload in value {
case i64:
}
```

That syntax is real Odin, but it is not automatically the clearest shape for
Kiln VM value logic.


## Aliases, Distinct Types, And Union Variants

`Name :: Existing_Type` creates an alias:

```odin
TokenAlias :: Token
```

An alias is interchangeable with the original type. In a union, this compiles:

```odin
ExprUnresolvedBinding :: Token

ExprDesc :: union {
    ExprUnresolvedBinding,
}
```

But `ExprUnresolvedBinding` is still only an alias for `Token`. Use this only
when that interchangeability is acceptable.

`distinct` creates a real named type with the same backing shape:

```odin
ExprUnresolvedBinding :: distinct Token

ExprDesc :: union {
    ExprUnresolvedBinding,
}
```

For distinct struct-backed types, field access still works directly:

```odin
expr := ExprUnresolvedBinding(token)
name := expr.value.(string)
```

Project rule:

- use an alias when the new name is only documentation
- use `distinct` when the union variant or domain value needs a real separate type
- do not wrap a single payload in a struct unless the wrapper adds real structure

This is useful for parser `ExprDesc` variants. A single-token expression payload
can be a distinct token-backed type instead of:

```odin
ExprUnresolvedBinding :: struct {
    token: Token,
}
```


## `if` Initial Statements

Odin supports `if` with an initial statement:

```odin
if value := compute(); value > 0 {
}
```

Project style does not prefer this for union assertions when it hides meaning:

```odin
if int_value, is_int := value.(i64); is_int {
}
```

Prefer the expanded form in VM helpers:

```odin
int_value, is_int := value.(i64)
if is_int {
}
```

This is a house readability rule, not an Odin limitation.


## Switches

Odin switch cases do not fall through by default.

This is valid:

```odin
switch opcode {
case .LOAD_CONST:
case .RETURN:
case:
}
```

Odin also has `#partial switch`.

Use `#partial switch` only when partial handling is explicitly intended. Do not
use it to silence an incomplete opcode implementation. If an opcode exists but
is not implemented, either implement it or do not expose it yet.


## Maps

Odin map basics:

```odin
items := make(map[string]vm.Value)
items["hp"] = vm.Value(i64(10))
value := items["hp"]
delete_key(&items, "hp")
```

Existence check:

```odin
value, exists := items["hp"]
```

Or:

```odin
exists := "hp" in items
```

Project map semantics are VM-level semantics, not automatically Odin map
semantics.

For Kiln maps:

- keys are VM string objects
- comparison is by string text
- backing key is Odin `string`
- missing get returns Kiln nil
- setting nil deletes the entry

Do not assume Odin map behavior is the language behavior. The VM opcode contract
decides that.


## Bit Fields

Odin `bit_field` is official syntax.

Project instruction layouts:

```odin
InstABC :: bit_field u32 {
    op: Opcode | 8,
    a:  u8     | 8,
    b:  u8     | 8,
    c:  u8     | 8,
}
```

Packing bytecode:

```odin
append(&generator_state.bytecode, u32(vm.InstABC{
    op = .ADD,
    a  = u8(dst),
    b  = u8(lhs),
    c  = u8(rhs),
}))
```

Decoding bytecode:

```odin
inst := InstABC(word)
```

Do not invent helper layers around this unless they remove real repeated
boundary logic.


## Unused Parameters

Do not add this by habit:

```odin
_ = return_slot_base
_ = requested_results
```

Only add unused suppression if the Odin compiler actually requires it in that
specific context.

If a parameter is part of an ABI and intentionally unused by one native proc,
the signature itself explains why it exists. Do not add noise unless the tool
requires it.


## Formatting And Style

Follow the local file.

Do not change comment style, indentation style, spacing style, enum ordering,
or section headings during unrelated edits.

Comments in this project are not decoration. They represent house style and
current mental model.

If adding comments:

- describe current behavior
- describe invariants
- describe operand contracts
- avoid meta-comments about why future code might change

Good:

```odin
// NEW_ARRAY A, B
// Creates an empty array in slot A. Length starts at 0.
// B reserves backing capacity for future pushes (B elements).
```

Bad:

```odin
// Capacity policy belongs to lowering/host code, not hidden VM defaults.
```

That second comment is meta commentary, not useful source explanation.


## Bytecode Gen Rules

`codegen` is mechanical proto construction.

It may:

- append encoded instruction words
- append constants to the proto constant pool
- track max slot used for `frame_slot_count`
- patch jump offsets
- finish a proto-backed function object
- build a runnable `vm.State`

It must not:

- know AST semantics
- lower expressions
- resolve locals
- know `if` or `while` as source constructs
- become a manager object
- add defensive append wrappers
- hide simple instruction construction behind unnecessary layers

Current singleton state should be plain package state:

```odin
generator_state := struct {
    name:             string,
    param_count:      int,
    bytecode:         [dynamic]u32,
    const_pool:       [dynamic]vm.Value,
    frame_slot_count: int,
}{}
```

Constant functions should name the produced kind:

```odin
const_int(20)
const_float(3.5)
const_string("hp")
```

Avoid ambiguous names like:

```odin
add_const_int
add_const_value
```

`gen.emit_add` emits numeric ADD. `gen.store_const_int` stores an int constant. Keep those
concepts separate.


## Slot Tracking In Bytecode Gen

Frame slot count is the highest register slot touched, plus one.

For an instruction using slots:

```odin
gen.emit_add(dst, lhs, rhs)
```

the generator must record all slots touched:

```odin
record_slots(dst, lhs, rhs)
```

This helper is earned because it centralizes an invariant:

```txt
frame_slot_count = max(slot index touched by this proto) + 1
```

Do not write repeated calls at every opcode:

```odin
track_slot(dst)
track_slot(lhs)
track_slot(rhs)
```

That is noisy and misses Odin's variadic tool.

Do not make callers pass frame slot counts manually unless there is a specific
reason. The generator is already seeing the slot operands. It can record the
count mechanically.


## Error Handling Discipline

Odin supports explicit error handling patterns like `or_return`.

Do not add error plumbing unless the surrounding proc has an error contract.

For Kiln prototype bytecode generation:

```odin
append(&generator_state.bytecode, word)
```

is the normal shape.

If allocation failure becomes a real design concern, change the API deliberately:

```odin
end_proto :: proc() -> (int, Error)
```

Do not fake an error policy with local panic wrappers at every append site.


## Known LLM Failure Modes For This Project

Do not do these:

- say Odin needs a named type before trying `:= struct {...}{}`
- add `_ = param` without a compiler requirement
- wrap `append` in invented allocation panic logic by default
- use C-shaped helper names and error paths because they feel familiar
- use `ok` everywhere when a named condition is clearer
- use compact `if init; cond` just because Odin supports it
- use type switches when direct assertions read better locally
- add stubs for unimplemented opcodes
- expose enum variants before implementing their VM behavior
- preserve bad names because they already exist
- add a helper because the plan mentioned one
- claim `Unknown in Odin` but then write guessed code anyway


## Verification Workflow

Before making a claim about Odin syntax:

1. Inspect nearby project code.
2. Search official docs or local Odin source.
3. If still uncertain, write a tiny probe.
4. Run:

```powershell
odin check path\to\probe -no-entry-point
```

5. Delete the probe.

For executable packages, use:

```powershell
odin run src
```

For package syntax probes without `main`, use `-no-entry-point`.


## Current Corrected gen Direction

This is the intended shape for first-pass bytecode generation:

```odin
gen.begin_proto("add_test", 0)

c20 := gen.store_const_int(20)
c22 := gen.store_const_int(22)

gen.emit_load_const(0, c20)
gen.emit_load_const(1, c22)
gen.emit_add(2, 0, 1)
gen.emit_return(2, 1)
gen.end_proto()

state := gen.build_vm_state()
```

Inside those procs:

```odin
record_slots(dst, lhs, rhs)

append(&generator_state.bytecode, u32(vm.InstABC{
    op = .ADD,
    a  = u8(dst),
    b  = u8(lhs),
    c  = u8(rhs),
}))
```

That is direct Odin. No manager. No wrapper stack. No fake lifecycle. No
allocator panic scaffolding.


## One-Line Rule

If the code exists only because the author did not know Odin, delete it or prove
it with the compiler.

