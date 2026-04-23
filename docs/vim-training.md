# Vim Training

This is a study manual for the Vim layer in this config.

Installed features covered here:

- Evil
- evil-surround
- evil-commentary
- evil-args
- evil-mc

The goal is not “know every key”. The goal is to think in edits.

## Mental Model

### 1. Think in units, not characters

Bad instinct:

- move one character at a time
- backspace through text
- select with the mouse

Better instinct:

- word
- line
- paragraph
- delimiter pair
- argument

### 2. Think in grammar

Most edits are:

- operator + motion
- operator + text object

Examples:

| Keys | Read it as |
| --- | --- |
| `dw` | delete to next word |
| `ciw` | change inner word |
| `da(` | delete around parens |
| `yap` | yank a paragraph |
| `2dd` | delete 2 lines |

### 3. Counts matter

Examples:

| Keys | Meaning |
| --- | --- |
| `3w` | move 3 words |
| `4j` | move down 4 lines |
| `2dd` | delete 2 lines |
| `3gcc` | comment 3 lines |

### 4. Repeat is a superpower

Use `.` whenever you just made one good change and want it again.

Example:

Before:

```text
foo_1
foo_2
foo_3
```

On `foo_1`:

- `cwbar<Esc>`

Result:

```text
bar
foo_2
foo_3
```

Move to next line and press:

- `.`

Repeat is often better than macros or multiple cursors when the same edit happens a few times in sequence.

## Editing Patterns

## Word Editing

### Change one word

Before:

```text
set mode slow
```

Cursor on `slow`:

- `ciwfast`

After:

```text
set mode fast
```

### Delete to next word

Before:

```text
alpha beta gamma
```

Cursor on `alpha`:

- `dw`

After:

```text
beta gamma
```

### Change to end of line

Before:

```text
set_property MODE OLD_VALUE
```

Cursor on `OLD_VALUE`:

- `C`

After typing `NEW_VALUE`:

```text
set_property MODE NEW_VALUE
```

## Line Editing

### Delete full lines

Before:

```text
line one
line two
line three
```

On `line one`:

- `2dd`

After:

```text
line three
```

### Change a full line

Before:

```text
temporary text
```

- `cc`

Type replacement, then:

```text
real text
```

### Join lines

Before:

```text
set mode
fast
```

- `J`

After:

```text
set mode fast
```

## Delimiter Editing

### Change inside quotes

Before:

```text
puts "old value"
```

Cursor anywhere inside:

- `ci"` then type `new value`

After:

```text
puts "new value"
```

### Delete around braces

Before:

```text
{alpha beta}
```

- `da{`

After:

```text

```

### Select inside parens

Before:

```text
call(alpha, beta)
```

On the inside:

- `vi(`

That gives a clean selection of the arguments without the delimiters.

## Argument Editing

This is one of the highest-value additions in this config.

Available text objects:

- `ia` inner argument
- `aa` outer argument

### Change one argument

Before:

```text
configure(port_a, mode_old, speed_fast)
```

Cursor on `mode_old`:

- `ciamode_new`

After:

```text
configure(port_a, mode_new, speed_fast)
```

### Delete one argument

Before:

```text
configure(port_a, mode_old, speed_fast)
```

Cursor on `mode_old`:

- `daa`

After:

```text
configure(port_a, speed_fast)
```

### Yank one argument

Before:

```text
configure(port_a, mode_old, speed_fast)
```

On `speed_fast`:

- `yia`

Now you can paste that exact argument elsewhere.

## Commenting

### Comment one line

Before:

```text
set debug 1
```

- `gcc`

After:

```text
# set debug 1
```

### Comment a paragraph

Before:

```text
set a 1
set b 2
set c 3
```

At the first line:

- `gcap`

### Comment a visual block

1. `V`
2. move with `j`
3. `gc`

This is usually the cleanest way to comment a small block interactively.

## Surround

### Add delimiters

Before:

```text
name
```

- `ysiw"`

After:

```text
"name"
```

### Wrap current line

Before:

```text
set mode fast
```

- `yss)`

After:

```text
(set mode fast)
```

### Change delimiters

Before:

```text
"name"
```

- `cs"'`

After:

```text
'name'
```

### Delete delimiters

Before:

```text
[name]
```

- `ds]`

After:

```text
name
```

## Multiple Cursors

Use multiple cursors when:

- the targets are repeated matches
- the edit is truly the same everywhere
- a macro would be harder to aim

### Basic flow

1. Put point on a symbol or make a selection.
2. Use `C-n` to add the next match.
3. Use `C-p` to add the previous match.
4. Use `grn` or `C-t` to skip a bad match.
5. Edit normally.
6. Use `grq` to clear all cursors.

### Example: rename repeated signal names

Before:

```text
set src_clk clk_main
connect clk_main pin_a
log clk_main
```

On `clk_main`:

- `C-n`
- `C-n`
- `C-n`
- `cwgclk_core<Esc>`

After:

```text
set src_clk clk_core
connect clk_core pin_a
log clk_core
```

### When not to use it

Do not use multiple cursors when the edit shape changes per match.

If each target needs a slightly different transformation, use:

- `.` if it is a repeated sequential edit
- a macro if the edit has a short fixed procedure

## Macros, Registers, Marks

These are core Evil/Vim tools and worth learning early.

## Macros

### Record a macro

- `qa` start recording into register `a`
- do the edit
- `q` stop recording

### Replay a macro

- `@a` replay once
- `3@a` replay 3 times

### Example: add semicolons

Before:

```text
set a 1
set b 2
set c 3
```

Record:

1. `qa`
2. `A;`
3. `<Esc>`
4. `j`
5. `q`

Replay:

- `2@a`

After:

```text
set a 1;
set b 2;
set c 3;
```

## Registers

Useful basics:

| Key | Meaning |
| --- | --- |
| `"ayy` | yank line into register `a` |
| `"ap` | paste register `a` |
| `:reg` | inspect registers |

Use registers when you want named storage, not just “last yank”.

## Marks

Useful basics:

| Key | Meaning |
| --- | --- |
| `ma` | set mark `a` |
| `` `a `` | jump exactly to mark `a` |
| `'a` | jump to mark `a` line |

Use marks when you need to jump back after a detour.

## Decision Guide

### Use `.` when

- you already performed one correct edit
- the next targets are nearby
- the edit is identical

### Use a macro when

- the edit is a short sequence
- it repeats line by line
- each repetition needs movement plus editing

### Use multiple cursors when

- the same text repeats in many places
- you want live simultaneous feedback
- the targets are matches of the same symbol or selection

### Use text objects when

- the edit target is structural
- you want “inside” or “around” semantics
- delimiters matter

### Use surround when

- the only job is adding, changing, or deleting delimiters

## Tcl-Oriented Examples

Tcl benefits a lot from:

- `ci{` and `di{`
- `ci"` and `di"`
- `cia` and `daa`
- `%` for delimiter matching

### Example: change braces content

Before:

```tcl
set cmd {run_full_build}
```

Cursor inside braces:

- `ci{run_quick_build`

After:

```tcl
set cmd {run_quick_build}
```

### Example: change quoted path

Before:

```tcl
set output_dir "build/debug"
```

- `ci"build/release`

After:

```tcl
set output_dir "build/release"
```

### Example: change one argument in a Tcl command

Before:

```tcl
set_property SEVERITY LOW [get_drc_checks NSTD-1]
```

Cursor on `LOW`:

- `ciaHIGH`

After:

```tcl
set_property SEVERITY HIGH [get_drc_checks NSTD-1]
```

### Example: delete one argument cleanly

Before:

```tcl
create_clock -name sys_clk -period 10.000 [get_ports clk]
```

Cursor on `-period 10.000` is not one “argument” pair in plain text, so edit in pieces:

- `daW` on `10.000` if using WORD-style motion
- or target the exact field with standard motions

For comma-delimited or list-like argument structures, `ia` and `aa` are much stronger.

### Example: nested structure

Before:

```tcl
set result [format "%s_%s" $block $mode]
```

Useful edits:

- `ci"` to replace the format string
- `%` to jump between brackets
- `cia` on `$mode` when inside the argument list

## Practice Drills

Run these on scratch text until the motions feel automatic.

### Drill 1: word changes

Start:

```text
alpha beta gamma delta
```

Tasks:

1. change `beta` to `BETA`
2. delete `gamma`
3. yank `alpha`

Suggested keys:

- `ciw`
- `dw`
- `yiw`

### Drill 2: surround

Start:

```text
signal_name
```

Tasks:

1. wrap in quotes
2. change quotes to brackets
3. remove brackets

Suggested keys:

- `ysiw"`
- `cs"]`
- `ds]`

### Drill 3: commentary

Start:

```text
set a 1
set b 2
set c 3
```

Tasks:

1. comment current line
2. uncomment it
3. comment the whole block

Suggested keys:

- `gcc`
- `gcc`
- `Vjjgc`

### Drill 4: arguments

Start:

```text
foo(arg1, arg2, arg3)
```

Tasks:

1. change `arg2`
2. delete `arg1`
3. select `arg3`

Suggested keys:

- `cia`
- `daa`
- `via`

### Drill 5: repeat

Start:

```text
old_a
old_b
old_c
```

Task:

Change each `old_*` to `new_*` using one real edit and `.`.

### Drill 6: macro

Start:

```text
set a 1
set b 2
set c 3
```

Task:

append `;` to every line with one macro.

### Drill 7: multiple cursors

Start:

```text
clk_main
clk_main
clk_main
```

Task:

change all three to `clk_core` with `evil-mc`.

## Final Heuristic

When you notice yourself:

- selecting text manually
- repeating the same backspace-heavy edit
- moving character by character

pause and ask:

1. What is the unit?
2. Is there a text object for it?
3. Can I do this once and repeat it?
4. Is this a macro?
5. Is this a multiple-cursor job?

That question is the real training. The keys follow from it.
