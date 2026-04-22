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

## Phase 1 Scope

Only implement:

- package manager bootstrap (elpaca)
- module/file structure
- Evil + evil-collection
- leader key system (general.el)
- which-key
- completion/navigation (vertico, orderless, consult, corfu)
- project.el integration
- perspective (context skeleton only)
- minimal UI cleanup
- backup and auto-save redirection

---

## Do NOT add yet

- magit
- dirvish
- org configuration
- LSP / DAP
- utility multiplexer implementation
- context templates (only skeleton)
- session restore system
- extra Vim plugins
- visual customization beyond basics

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
