# Org Workflow

## Files

Primary Org directory:

- `~/org/`

Expected core files:

- `inbox.org`
- `tasks.org`
- `projects.org`
- `notes.org`
- `journal.org`

The agenda file list is built dynamically from all `.org` files under `~/org/`.

## TODO States

Workflow:

- `TODO`
- `NEXT`
- `IN-PROGRESS`
- `WAIT`
- `DONE`
- `CANCELLED`

Notes:

- `DONE` and `CANCELLED` are terminal states.
- State changes are logged with timestamps.
- Logs go into a `LOGBOOK` drawer.
- Moving a task to `WAIT` prompts for a note.

## Capture

Main commands:

| Key | Target | Use |
| --- | --- | --- |
| `SPC n c` | capture menu | choose any template |
| `SPC n t` | `inbox.org` | quick task capture |
| `SPC n N` | `notes.org` | quick note |
| `SPC n j` | `journal.org` | journal entry |

Templates:

- inbox task
- quick note
- journal entry

Example:

1. Press `SPC n t`
2. Write the task
3. Finish with `C-c C-c`
4. Refile later with `SPC m r`

## Refile

Refile is configured across headings in the Org files under `~/org/`.

Main use:

- capture quickly into inbox
- sort later into `tasks.org`, `projects.org`, or another Org file

Commands:

- in Org buffer: `SPC m r`
- in agenda: `SPC m r`

## Agenda Dashboard

Main command:

- `SPC n a`

Context entry:

- `SPC x a`

The default dashboard is one custom work view with:

- `Schedule`
- `In Progress`
- `Next`
- `Waiting`
- `Inbox`
- `Triage`

Meaning:

- `Schedule`: today’s scheduled items and deadlines
- `In Progress`: active work already underway
- `Next`: ready-to-pull tasks
- `Waiting`: blocked or delegated work
- `Inbox`: raw `TODO` items from `inbox.org`
- `Triage`: unscheduled `TODO` items from other Org files

## Agenda Usage

In agenda:

- `j` / `k` move up and down
- `RET` visits the selected item in the `notes` context
- `SPC m t` changes TODO state
- `SPC m s` schedules
- `SPC m d` sets deadline
- `SPC m r` refiles
- `SPC m a` archives

## Practical Examples

### Capture a task fast

1. `SPC n t`
2. Enter: `Fix Dired refresh issue`
3. `C-c C-c`

### Move it out of inbox later

1. Open inbox or agenda
2. Put point on the task
3. Press `SPC m r`
4. Choose a heading under `tasks.org` or `projects.org`

### Mark work as blocked

1. Put point on a task
2. Press `SPC m t`
3. Change state to `WAIT`
4. Enter the note when prompted

### Review the day

1. `SPC n a`
2. Check `In Progress`, `Next`, and `Waiting`
3. Visit items with `RET`
