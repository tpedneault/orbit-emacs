# Vim Reference

This config is Evil-first. The goal is to keep the editing language close to Vim habits:

- operators + motions
- text objects
- surround editing
- commentary
- argument objects
- modal multiple cursors

## Core Pattern

Most edits follow:

- operator + motion
- operator + text object

Examples:

| Keys | Meaning |
| --- | --- |
| `dw` | delete word |
| `ciw` | change inner word |
| `dap` | delete a paragraph |
| `y$` | yank to end of line |

## Useful Operators

| Operator | Meaning |
| --- | --- |
| `d` | delete |
| `c` | change |
| `y` | yank |
| `v` | visual select |
| `>` / `<` | indent |

## Useful Motions

| Motion | Meaning |
| --- | --- |
| `w` / `b` / `e` | word motions |
| `0` / `^` / `$` | line start / first non-blank / end |
| `f<char>` / `t<char>` | find to character |
| `{` / `}` | paragraph movement |
| `%` | matching pair |

## Core Text Objects

| Text Object | Meaning |
| --- | --- |
| `iw` / `aw` | inner / a word |
| `i"` / `a"` | inside / around quotes |
| `i(` / `a(` | inside / around parens |
| `i{` / `a{` | inside / around braces |

Examples:

| Keys | Result |
| --- | --- |
| `ci"` | replace string contents |
| `da(` | delete a parenthesized form |
| `vi{` | select inside braces |

## Surround

Provided by `evil-surround`.

Examples:

| Keys | Meaning |
| --- | --- |
| `ysiw"` | surround inner word with `"` |
| `cs"'` | change `"` surround to `'` |
| `ds"` | delete `"` surround |
| `yss)` | surround current line |

## Commentary

Provided by `evil-commentary`.

Examples:

| Keys | Meaning |
| --- | --- |
| `gcc` | comment current line |
| `gcj` | comment current line and next line |
| `gc}` | comment to next paragraph |
| visual `gc` | comment selection |

## Argument Text Objects

Provided by `evil-args`.

Available objects:

- `ia` inner argument
- `aa` outer argument

These are especially useful for Tcl calls, Lisp-like argument lists, and function calls.

Examples:

| Keys | Meaning |
| --- | --- |
| `cia` | change current argument |
| `daa` | delete current argument including separator context |
| `via` | select inner argument |
| `vaa` | select outer argument |

Example target:

```text
foo(arg1, arg2, arg3)
```

With point on `arg2`:

- `cia` changes only `arg2`
- `daa` removes the full argument cleanly

## Multiple Cursors

Provided by `evil-mc`.

This stays inside the Evil workflow rather than introducing a separate non-modal editing system.

Guidelines:

- use it for repeated structured edits
- keep the edit simple and deterministic
- drop back to normal single-cursor editing when the shape diverges

## Practical Editing Patterns

### Rename inside quotes

```text
call "old_name"
```

Use:

- move onto the string
- `ci"` then type the new name

### Replace one argument in a Tcl-style command

```text
set_property VALUE OLD target_obj
```

Use:

- move onto `OLD`
- `cia` then type the new value

### Comment a small block

Use:

1. `V` to select lines
2. `j` / `k` to extend selection
3. `gc`

### Wrap existing text

Use:

1. move onto the word
2. `ysiw]`

Result:

```text
[word]
```
