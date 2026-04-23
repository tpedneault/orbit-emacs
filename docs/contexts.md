# Contexts

This config uses Perspective as a context/workspace layer.

The model is:

- one task, one context
- stable names
- minimal setup
- no tab-based workflow

## Core Rules

- Contexts are workspaces, not tabs.
- Reuse an existing context when it already matches the task.
- Context templates should open a clean starting point, not a complex layout.
- The agenda context is a dashboard, not a place to do deep editing.

## Manual Context Commands

| Command | Purpose |
| --- | --- |
| `SPC x x` | switch to an existing context or create one by name |
| `SPC x n` | create a blank context |
| `SPC x d` | delete a context |
| `SPC x r` | rename current context |
| `SPC x [` / `SPC x ]` | move between contexts |

## Template Contexts

### `edit/<project>`

Key: `SPC x e`

Use it when you want to enter a project-focused editing workspace.

- If current buffer is already in a project, that project is used.
- Otherwise you are prompted for a known project.
- The command switches to or creates `edit/<project-name>`.
- It does not force `project-find-file`; it just puts you in the right workspace.

### `git/<project>`

Key: `SPC x g`

Use it for repository review, staging, and commit flow.

- Requires a project or Git repo.
- Switches to or creates `git/<project-name>`.
- Opens Magit status.
- Collapses to a single-purpose window.

### `files/<project-or-dir>`

Key: `SPC x f`

Use it for deliberate file management.

- In a project: `files/<project-name>`
- Outside a project: `files/<directory-name>`
- Opens built-in Dired at the relevant root.

### `notes`

Key: `SPC x o`

Use it for notes and Org entry editing.

- Opens the main notes file.
- Agenda item visits are routed here on purpose.

### `agenda`

Key: `SPC x a`

Use it as the planning dashboard.

- Opens the custom Org dashboard.
- Starts in a clean single-window state.
- Visiting an item keeps this context intact and opens the item in `notes`.

### `scratch`

Key: `SPC x s`

Use it for temporary work that should not pollute a project context.

## Session Support

Contexts can be saved and restored manually:

- `SPC q s` save session
- `SPC q l` load session

This is manual only. There is no automatic save on exit or restore on startup.
