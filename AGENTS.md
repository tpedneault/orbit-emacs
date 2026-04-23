# Emacs Configuration — Agent Instructions

## Philosophy

This is a handcrafted Emacs configuration.

Core principles:
- modal (Evil-first)
- keyboard-driven (SPC leader)
- minimal, text-first UI
- consistent command language
- optimized for muscle memory and Vim mastery
- no unnecessary packages or UI clutter

Do not redesign the architecture unless explicitly asked.

---

## Phase 2 Scope

Only implement:

- session restore foundation (manual, perspective-based)
- Magit foundation
- Dired/file management refinement
- Org/agenda basics

Keep all implementations minimal and consistent with the existing architecture. Do not expand scope beyond what is listed.

---

## Do NOT add yet

- LSP / DAP
- utility multiplexer implementation
- advanced Vim plugins (surround, commentary, etc.)
- Dirvish (use Dired only for now)
- large UI customizations or theme packs
- dashboard/startup UI packages
- context templates beyond minimal stubs
- multiple session profiles or automatic session restore

---

## Session constraints

- session restore must be manual (no auto-save or auto-load yet)
- use persp-mode persistence as the foundation
- store session data in the config-local var/ directory
- do not use desktop-save-mode
- do not use external session packages

---

## File Structure

- early-init.el
- init.el
- modules/
  - mod-core.el
  - mod-ui.el
  - mod-evil.el
  - mod-keys.el
  - mod-completion.el
  - mod-project.el
  - mod-context.el
  - mod-session.el
  - mod-git.el
  - mod-dired.el
  - mod-org.el

Keep code modular and consistent.

---

## Keybinding System

Global leader: SPC

Groups:
- SPC f files
- SPC b buffers
- SPC p projects
- SPC w windows
- SPC g git
- SPC o utility
- SPC n notes
- SPC x contexts
- SPC t toggles
- SPC q quit
- SPC m local leader

Contexts (SPC x):
- x switch
- n new
- d delete
- r rename
- [ previous
- ] next
- g git
- f files
- o notes
- a agenda
- s scratch

---

## Implementation Rules

- make minimal, high-confidence changes
- do not introduce unnecessary packages
- keep behavior predictable
- explain all changes clearly
- prefer explicit, readable code over clever abstractions

---

## Testing

After each change:
- ensure Emacs starts without errors
- verify keybindings work
- verify modules load correctly