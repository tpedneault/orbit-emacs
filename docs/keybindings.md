# Keybindings

## Global Shortcuts

| Key | Action | Notes |
| --- | --- | --- |
| `SPC SPC` | `consult-buffer` | fast buffer switch |
| `SPC .` | `project-find-file` | current project |
| `SPC /` | `mod-project-search` | ripgrep in project |
| `SPC :` | `execute-extended-command` | `M-x` |
| `SPC ,` | local leader | same target as `SPC m` |

## `SPC f` Files

| Key | Action | Notes |
| --- | --- | --- |
| `SPC f f` | `find-file` | open file |
| `SPC f s` | `save-buffer` | save current buffer |

## `SPC b` Buffers

| Key | Action | Notes |
| --- | --- | --- |
| `SPC b b` | `consult-buffer` | `switch-to-buffer` is remapped |
| `SPC b d` | `kill-current-buffer` | kill buffer |

## `SPC p` Projects

| Key | Action | Notes |
| --- | --- | --- |
| `SPC p p` | `project-switch-project` | switch project |
| `SPC p f` | `project-find-file` | find project file |
| `SPC p s` | `mod-project-search` | project ripgrep |

## `SPC w` Windows

| Key | Action | Notes |
| --- | --- | --- |
| `SPC w w` | `other-window` | cycle windows |
| `SPC w h` | `windmove-left` | move left |
| `SPC w j` | `windmove-down` | move down |
| `SPC w k` | `windmove-up` | move up |
| `SPC w l` | `windmove-right` | move right |
| `SPC w d` | `delete-window` | close window |
| `SPC w o` | `delete-other-windows` | single window |
| `SPC w s` | `split-window-below` | split below |
| `SPC w v` | `split-window-right` | split right |

## `SPC g` Git

| Key | Action | Notes |
| --- | --- | --- |
| `SPC g g` | `mod-git-status` | Magit status |
| `SPC g l` | `mod-git-log` | current repo log |
| `SPC g b` | `mod-git-blame` | blame current file |

## `SPC o` Utility Bay

| Key | Action | Notes |
| --- | --- | --- |
| `SPC o o` | `mod-utility-toggle` | close or reopen utility bay |
| `SPC o s` | `mod-utility-shell` | built-in shell |
| `SPC o m` | `mod-utility-messages` | `*Messages*` |
| `SPC o h` | `mod-utility-help` | `*Help*` or `*Apropos*` |
| `SPC o c` | `mod-utility-compilation` | `*compilation*` |

## `SPC n` Notes / Org

| Key | Action | Notes |
| --- | --- | --- |
| `SPC n n` | `mod-org-open-notes` | open `notes.org` |
| `SPC n a` | `mod-org-open-agenda` | open work dashboard |
| `SPC n c` | `mod-org-capture` | capture dispatcher |
| `SPC n t` | `mod-org-capture-inbox-task` | inbox task capture |
| `SPC n j` | `mod-org-capture-journal` | journal capture |
| `SPC n N` | `mod-org-capture-note` | quick note capture |

## `SPC x` Contexts

| Key | Action | Notes |
| --- | --- | --- |
| `SPC x x` | `mod-context-switch` | switch or create by name |
| `SPC x n` | `mod-context-new` | new blank context |
| `SPC x d` | `mod-context-delete` | delete context |
| `SPC x r` | `mod-context-rename` | rename context |
| `SPC x [` | `mod-context-previous` | previous context |
| `SPC x ]` | `mod-context-next` | next context |
| `SPC x e` | `mod-context-editor` | `edit/<project>` |
| `SPC x g` | `mod-context-git` | `git/<project>` |
| `SPC x f` | `mod-context-files` | `files/<project-or-dir>` |
| `SPC x o` | `mod-context-notes` | `notes` context |
| `SPC x a` | `mod-context-agenda` | `agenda` context |
| `SPC x s` | `mod-context-scratch` | `scratch` context |

## `SPC q` Quit / Session

| Key | Action | Notes |
| --- | --- | --- |
| `SPC q s` | `mod-session-save` | save Perspective session |
| `SPC q l` | `mod-session-load` | load Perspective session |
| `SPC q q` | `save-buffers-kill-terminal` | quit Emacs |

## `SPC m` Local Leader

### Org Buffer

| Key | Action | Notes |
| --- | --- | --- |
| `SPC m t` | `org-todo` | change TODO state |
| `SPC m s` | `org-schedule` | schedule |
| `SPC m d` | `org-deadline` | deadline |
| `SPC m r` | `org-refile` | refile heading |
| `SPC m a` | `org-archive-subtree` | archive subtree |
| `SPC m p` | `org-priority` | priority |

### Agenda Buffer

| Key | Action | Notes |
| --- | --- | --- |
| `j` | `org-agenda-next-line` | Vim-style movement |
| `k` | `org-agenda-previous-line` | Vim-style movement |
| `RET` | `mod-org-agenda-visit` | open item in notes context |
| `SPC m t` | `org-agenda-todo` | change state |
| `SPC m s` | `org-agenda-schedule` | schedule |
| `SPC m d` | `org-agenda-deadline` | deadline |
| `SPC m r` | `org-agenda-refile` | refile |
| `SPC m a` | `org-agenda-archive` | archive |
| `SPC m v` | `mod-org-agenda-visit` | visit selected item |
