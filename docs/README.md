# Emacs Config

This is a modular, Evil-first Emacs configuration built around a small set of strong defaults:

- modal editing with Evil
- `SPC` leader for global commands
- Perspective contexts for task separation
- built-in Org for notes, tasks, capture, and agenda
- minimal GUI with text-first defaults

## Philosophy

- Modal: normal-state editing is the default.
- Context-based: work is split into named workspaces such as `edit/<project>`, `git/<project>`, `notes`, and `agenda`.
- Minimal UI: no dashboard, no sidebar, no decorative packages, no custom modeline framework.
- Predictable: built-in features are preferred unless a package clearly earns its place.

## Layout

Core files:

- [early-init.el](/Users/thomas/.config/emacs/early-init.el)
- [init.el](/Users/thomas/.config/emacs/init.el)

Modules:

- [modules/mod-core.el](/Users/thomas/.config/emacs/modules/mod-core.el): bootstrap, file hygiene, Elpaca
- [modules/mod-ui.el](/Users/thomas/.config/emacs/modules/mod-ui.el): font, theme, line numbers, modeline context label
- [modules/mod-evil.el](/Users/thomas/.config/emacs/modules/mod-evil.el): Evil, Evil Collection, surround, commentary, args, multiple cursors
- [modules/mod-keys.el](/Users/thomas/.config/emacs/modules/mod-keys.el): leader keys and local leaders
- [modules/mod-completion.el](/Users/thomas/.config/emacs/modules/mod-completion.el): Vertico, Orderless, Consult, Corfu, Marginalia
- [modules/mod-project.el](/Users/thomas/.config/emacs/modules/mod-project.el): built-in `project.el`
- [modules/mod-context.el](/Users/thomas/.config/emacs/modules/mod-context.el): Perspective contexts and templates
- [modules/mod-org.el](/Users/thomas/.config/emacs/modules/mod-org.el): Org files, TODO flow, capture, refile, agenda dashboard
- [modules/mod-git.el](/Users/thomas/.config/emacs/modules/mod-git.el): Magit entry points
- [modules/mod-dired.el](/Users/thomas/.config/emacs/modules/mod-dired.el): built-in Dired foundation
- [modules/mod-utility.el](/Users/thomas/.config/emacs/modules/mod-utility.el): reusable bottom utility bay
- [modules/mod-session.el](/Users/thomas/.config/emacs/modules/mod-session.el): manual context session save/load

## Main Ideas

- `SPC` is the global command layer.
- `SPC m` is the local leader.
- `SPC x` manages contexts.
- `SPC n` drives notes, capture, and agenda.
- `SPC o` opens a reusable bottom utility window.
- `SPC f c` gives quick access to the config itself.

For practical lookup, start here:

- [docs/keybindings.md](/Users/thomas/.config/emacs/docs/keybindings.md)
- [docs/workflow.md](/Users/thomas/.config/emacs/docs/workflow.md)
- [docs/contexts.md](/Users/thomas/.config/emacs/docs/contexts.md)
- [docs/org.md](/Users/thomas/.config/emacs/docs/org.md)
- [docs/vim.md](/Users/thomas/.config/emacs/docs/vim.md)
