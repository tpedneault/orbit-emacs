# Emacs Configuration

Handcrafted Emacs config for modal, keyboard-first work.

This setup is built around a few strong ideas:

- Evil-first editing
- Perspective-based contexts/workspaces
- minimal, text-first UI
- practical Org workflow
- small, composable command language under `SPC`

## Design Principles

- Modal: normal state is the default editing mode.
- Context-based: tasks live in named workspaces like `edit/<project>`, `git/<project>`, `notes`, and `agenda`.
- Minimal UI: built-in theme, built-in modeline, no dashboard, no sidebar, no decorative packages.
- Keyboard-driven: leader system, local leaders, Consult-based navigation, and Vim-oriented editing.

## Feature Overview

- Contexts/workspaces: Perspective-backed task separation with templates for edit, git, files, notes, agenda, and scratch.
- Org workflow: inbox capture, notes, journal, refile, and a custom work dashboard.
- Vim mastery layer: Evil, Evil Collection, surround, commentary, argument text objects, and modal multiple cursors.
- Utility bay: one reusable bottom window for shell, messages, help, and compilation.

## Quick Start

This repo is an Emacs config directory. Use it as your `~/.config/emacs/`.

Launch Emacs normally, then start with:

First keys to know:

- `SPC SPC` switch buffers
- `SPC .` find a file in the current project
- `SPC /` search the current project
- `SPC x e` jump into an editing context
- `SPC x a` open the agenda dashboard context
- `SPC n t` capture an inbox task

## Docs

- [docs/README.md](docs/README.md)
- [docs/keybindings.md](docs/keybindings.md)
- [docs/workflow.md](docs/workflow.md)
- [docs/contexts.md](docs/contexts.md)
- [docs/org.md](docs/org.md)
- [docs/vim.md](docs/vim.md)
- [docs/vim-training.md](docs/vim-training.md)
