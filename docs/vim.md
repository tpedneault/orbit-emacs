# Vim Quick Reference

Installed Vim layer:

- Evil
- evil-surround
- evil-commentary
- evil-args
- evil-mc

## Core Grammar

Think in:

- operator + motion
- operator + text object
- count + operator + motion

Examples:

| Keys | Meaning |
| --- | --- |
| `dw` | delete to next word |
| `ciw` | change inner word |
| `2dd` | delete 2 lines |
| `y$` | yank to end of line |
| `dap` | delete a paragraph |
| `.` | repeat last change |

## Operators

| Key | Meaning |
| --- | --- |
| `d` | delete |
| `c` | change |
| `y` | yank |
| `v` | character visual |
| `V` | line visual |
| `>` / `<` | indent / unindent |

## Motions

| Key | Meaning |
| --- | --- |
| `w` `e` `b` | next word start, end, previous word |
| `0` `^` `$` | line start, first non-blank, line end |
| `f<char>` | to character |
| `t<char>` | before character |
| `;` `,` | repeat / reverse `f` or `t` |
| `%` | matching delimiter |
| `{` `}` | paragraph backward / forward |
| `gg` `G` | top / bottom of buffer |

## Text Objects

| Key | Meaning |
| --- | --- |
| `iw` / `aw` | inner / a word |
| `i"` / `a"` | inside / around quotes |
| `i'` / `a'` | inside / around single quotes |
| `i(` / `a(` | inside / around parens |
| `i[` / `a[` | inside / around brackets |
| `i{` / `a{` | inside / around braces |
| `ip` / `ap` | inner / a paragraph |

Examples:

| Keys | Result |
| --- | --- |
| `ci"` | replace text inside quotes |
| `da(` | delete a full parenthesized form |
| `vi{` | select inside braces |
| `yap` | yank a whole paragraph |

## Surround

Provided by `evil-surround`.

| Keys | Meaning |
| --- | --- |
| `ysiw"` | surround inner word with `"` |
| `ysiw]` | surround inner word with `[` `]` |
| `yss)` | surround current line with `(` `)` |
| `S"` | surround a visual selection with `"` |
| `cs"'` | change `"` to `'` |
| `cs]"` | change `[` `]` to `"` |
| `ds"` | delete quote surround |

Short examples:

```text
name
```

`ysiw"` ->

```text
"name"
```

## Commentary

Provided by `evil-commentary`.

| Keys | Meaning |
| --- | --- |
| `gcc` | comment current line |
| `3gcc` | comment 3 lines |
| `gcj` | comment current line and next line |
| `gcap` | comment paragraph |
| visual `gc` | comment selection |

## Argument Text Objects

Provided by `evil-args`.

Available:

- `ia` inner argument
- `aa` outer argument

| Keys | Meaning |
| --- | --- |
| `cia` | change current argument |
| `daa` | delete current argument |
| `yia` | yank current argument |
| `via` | select inner argument |
| `vaa` | select outer argument |

Example:

```text
foo(arg1, arg2, arg3)
```

On `arg2`:

- `cia` changes only `arg2`
- `daa` removes the whole argument region cleanly

## Multiple Cursors

Provided by `evil-mc`.

Common default commands:

| Keys | Command | Use |
| --- | --- | --- |
| `C-n` | `evil-mc-make-and-goto-next-match` | add next match |
| `C-p` | `evil-mc-make-and-goto-prev-match` | add previous match |
| `M-n` | `evil-mc-make-and-goto-next-cursor` | move to next cursor |
| `M-p` | `evil-mc-make-and-goto-prev-cursor` | move to previous cursor |
| `grn` or `C-t` | `evil-mc-skip-and-goto-next-match` | skip next match |
| `grp` | `evil-mc-skip-and-goto-prev-match` | skip previous match |
| `gru` | `evil-mc-undo-last-added-cursor` | remove last cursor |
| `grq` | `evil-mc-undo-all-cursors` | clear all cursors |

Use it for repeated, same-shape edits. If the edit path diverges, go back to one cursor or a macro.

## Fast Patterns

### Rename inside quotes

```text
set name "old_value"
```

Move onto the string, then:

- `ci"` type new value

### Replace one Tcl argument

```text
set_property MODE OLD target_obj
```

Move onto `OLD`, then:

- `cia` type replacement

### Comment a block

1. `V`
2. move with `j` / `k`
3. `gc`

### Wrap a symbol

```text
signal_name
```

`ysiw]` ->

```text
[signal_name]
```
