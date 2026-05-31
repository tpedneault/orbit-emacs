;;; mod-theme.el --- Orbit visual identity -*- lexical-binding: t; -*-

;;; Commentary:
;; Defines Orbit custom themes, including dark, light, and retro variants,
;; a recommended font stack with graceful fallback, and the `mod-theme-load' /
;; `mod-theme-select' commands.
;;
;; Load order: mod-core → mod-theme → mod-home → mod-ui
;; This ensures themes are active before mod-ui applies the modeline.

;;; Code:

(require 'seq)

;; ─── Face declarations ────────────────────────────────────────────────────────
;; Every orbit-* face is declared with `defface' before the deftheme blocks.
;; This guarantees that the face symbols are valid (facep returns t) regardless
;; of whether a theme has been enabled yet.  The deftheme / custom-theme-set-faces
;; blocks below override every spec; these are the safe fallbacks only.

(defgroup orbit-faces nil
  "Faces used by orbit-emacs visual modules."
  :group 'faces)

;; Modeline
(defface orbit-modeline-evil-normal
  '((t (:inherit mode-line :weight bold))) "Normal evil-state modeline segment." :group 'orbit-faces)
(defface orbit-modeline-evil-insert
  '((t (:inherit mode-line))) "Insert evil-state modeline segment." :group 'orbit-faces)
(defface orbit-modeline-evil-visual
  '((t (:inherit mode-line))) "Visual evil-state modeline segment." :group 'orbit-faces)
(defface orbit-modeline-evil-replace
  '((t (:inherit mode-line))) "Replace evil-state modeline segment." :group 'orbit-faces)
(defface orbit-modeline-evil-emacs
  '((t (:inherit mode-line))) "Emacs evil-state modeline segment." :group 'orbit-faces)
(defface orbit-modeline-evil-motion
  '((t (:inherit mode-line))) "Motion evil-state modeline segment." :group 'orbit-faces)
(defface orbit-modeline-context
  '((t (:inherit mode-line))) "Context/project segment of the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-context-edit
  '((t (:inherit orbit-modeline-context :weight bold))) "Project edit context in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-context-git
  '((t (:inherit orbit-modeline-context :weight bold))) "Git context in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-context-files
  '((t (:inherit orbit-modeline-context :weight bold))) "Files context in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-context-notes
  '((t (:inherit orbit-modeline-context :weight bold))) "Notes and agenda context in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-context-roam
  '((t (:inherit orbit-modeline-context :weight bold))) "Roam and loose edit context in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-context-scratch
  '((t (:inherit orbit-modeline-context :weight bold))) "Scratch context in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-buffer
  '((t (:inherit mode-line :weight bold))) "Buffer name segment of the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-brand
  '((t (:inherit mode-line :weight bold))) "Orbit brand badge in the modeline." :group 'orbit-faces)
(defface orbit-modeline-separator
  '((t (:inherit mode-line))) "Orbit separator in the modeline." :group 'orbit-faces)
(defface orbit-modeline-state-modified
  '((t (:inherit mode-line :weight bold))) "Modified marker in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-state-read-only
  '((t (:inherit mode-line :weight bold))) "Read-only marker in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-state-narrowed
  '((t (:inherit mode-line :weight bold))) "Narrowed marker in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-borrowed
  '((t (:inherit mode-line :weight bold))) "Borrowed-buffer marker in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-vc
  '((t (:inherit mode-line))) "Version-control segment in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-mode
  '((t (:inherit mode-line))) "Major mode segment of the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-meta
  '((t (:inherit mode-line))) "Low-noise metadata segment in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-position
  '((t (:inherit mode-line :weight bold))) "Cursor position segment in the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-right
  '((t (:inherit mode-line))) "Right-hand segment of the orbit modeline." :group 'orbit-faces)

;; Header line
(defface orbit-header-context
  '((t (:inherit header-line :weight bold))) "Context name in the orbit header line." :group 'orbit-faces)
(defface orbit-header-context-edit
  '((t (:inherit orbit-header-context))) "Project edit context in the orbit header line." :group 'orbit-faces)
(defface orbit-header-context-git
  '((t (:inherit orbit-header-context))) "Git context in the orbit header line." :group 'orbit-faces)
(defface orbit-header-context-files
  '((t (:inherit orbit-header-context))) "Files context in the orbit header line." :group 'orbit-faces)
(defface orbit-header-context-notes
  '((t (:inherit orbit-header-context))) "Notes and agenda context in the orbit header line." :group 'orbit-faces)
(defface orbit-header-context-roam
  '((t (:inherit orbit-header-context))) "Roam and loose edit context in the orbit header line." :group 'orbit-faces)
(defface orbit-header-context-scratch
  '((t (:inherit orbit-header-context))) "Scratch context in the orbit header line." :group 'orbit-faces)
(defface orbit-header-sep
  '((t (:inherit header-line))) "Separator glyph in the orbit header line." :group 'orbit-faces)
(defface orbit-header-path
  '((t (:inherit header-line))) "File path in the orbit header line." :group 'orbit-faces)
(defface orbit-header-clock
  '((t (:inherit header-line :slant italic))) "Clock segment in the orbit header line." :group 'orbit-faces)

;; Menu strip / dropdowns
(defface orbit-menu-strip
  '((t (:inherit header-line))) "Background face for the Orbit menu strip." :group 'orbit-faces)
(defface orbit-menu-label
  '((t (:inherit header-line))) "Top-level Orbit menu label." :group 'orbit-faces)
(defface orbit-menu-label-active
  '((t (:inherit header-line :weight bold))) "Active or hovered Orbit menu label." :group 'orbit-faces)
(defface orbit-menu-dropdown
  '((t (:inherit default))) "Background face for Orbit menu dropdowns." :group 'orbit-faces)
(defface orbit-menu-dropdown-title
  '((t (:inherit font-lock-keyword-face :weight bold))) "Title face for Orbit menu dropdowns." :group 'orbit-faces)
(defface orbit-menu-dropdown-heading
  '((t (:inherit font-lock-comment-face :weight bold))) "Section heading face for Orbit menu dropdowns." :group 'orbit-faces)
(defface orbit-menu-dropdown-command
  '((t (:inherit default))) "Command row face for Orbit menu dropdowns." :group 'orbit-faces)
(defface orbit-menu-dropdown-disabled
  '((t (:inherit shadow))) "Disabled command row face for Orbit menu dropdowns." :group 'orbit-faces)

;; Home / dashboard
(defface orbit-home-logo
  '((t (:weight bold))) "ASCII logo in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-tagline
  '((t (:slant italic))) "Tagline in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-clock
  '((t nil)) "Active clock in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-section
  '((t (:weight bold))) "Section heading in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-key
  '((t (:weight bold))) "Key hint in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-project
  '((t nil)) "Project name in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-path
  '((t (:slant italic))) "Project path in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-todo
  '((t nil)) "Task entry in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-state-next
  '((t (:weight bold))) "NEXT task state in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-state-in-progress
  '((t (:weight bold))) "IN-PROGRESS task state in the orbit home buffer." :group 'orbit-faces)
(defface orbit-home-state-wait
  '((t (:weight bold))) "WAIT task state in the orbit home buffer." :group 'orbit-faces)

;; ─── orbit-dark ──────────────────────────────────────────────────────────────

(deftheme orbit-dark "Orbit dark theme — deep navy with warm amber accent.")

(let* ((bg-main     "#1a1b26")
       (bg-dim      "#24283b")
       (bg-hl       "#292e42")
       (bg-inactive "#414868")
       (fg-main     "#c0caf5")
       (fg-dim      "#787c99")
       (amber       "#e0af68")
       (blue        "#7aa2f7")
       (purple      "#bb9af7")
       (green       "#9ece6a")
       (red         "#f7768e")
       (orange      "#ff9e64")
       (cyan        "#7dcfff")
       (bg-dark     "#13141f")
       ;; Diff bg tints
       (diff-add-bg "#1e2d1e")
       (diff-add-hl "#243424")
       (diff-rem-bg "#2d1e1e")
       (diff-rem-hl "#3a2424"))
  (custom-theme-set-faces
   'orbit-dark
   ;; ── Core UI ──────────────────────────────────────────────────────────────
   `(default                        ((t (:background ,bg-main :foreground ,fg-main))))
   `(cursor                         ((t (:background ,amber))))
   `(fringe                         ((t (:background ,bg-main :foreground ,fg-dim))))
   `(region                         ((t (:background ,bg-hl :extend t))))
   `(highlight                      ((t (:background ,bg-hl))))
   `(hl-line                        ((t (:background ,bg-hl :extend t))))
   `(minibuffer-prompt              ((t (:foreground ,amber :weight bold))))
   `(isearch                        ((t (:background ,amber :foreground ,bg-main :weight bold))))
   `(isearch-fail                   ((t (:background ,red :foreground ,bg-main))))
   `(lazy-highlight                 ((t (:background ,bg-hl :foreground ,fg-main))))
   `(match                          ((t (:background ,bg-hl :foreground ,amber))))
   `(line-number                    ((t (:background ,bg-main :foreground ,fg-dim))))
   `(line-number-current-line       ((t (:background ,bg-main :foreground ,amber :weight bold))))
   `(mode-line                      ((t (:background ,bg-dim :foreground ,fg-main :box nil))))
   `(mode-line-inactive             ((t (:background ,bg-inactive :foreground ,fg-dim :box nil))))
   `(mode-line-buffer-id            ((t (:foreground ,fg-main :weight bold))))
   `(header-line                    ((t (:background ,bg-dark :foreground ,fg-dim :box nil :inherit nil))))
   `(vertical-border                ((t (:foreground ,bg-dim))))
   `(window-divider                 ((t (:foreground ,bg-dim))))
   `(window-divider-first-pixel     ((t (:foreground ,bg-dim))))
   `(window-divider-last-pixel      ((t (:foreground ,bg-dim))))
   `(fill-column-indicator          ((t (:foreground ,bg-hl))))
   `(link                           ((t (:foreground ,blue :underline t))))
   `(link-visited                   ((t (:foreground ,purple :underline t))))
   `(error                          ((t (:foreground ,red :weight bold))))
   `(warning                        ((t (:foreground ,orange :weight bold))))
   `(success                        ((t (:foreground ,green :weight bold))))
   `(shadow                         ((t (:foreground ,fg-dim))))
   `(secondary-selection            ((t (:background ,bg-hl))))
   `(mod-evil-pulse                 ((t (:background ,amber))))
   `(trailing-whitespace            ((t (:background ,red))))
   `(whitespace-tab                 ((t (:foreground ,bg-hl :background ,bg-main))))
   `(whitespace-trailing            ((t (:background ,red))))
   ;; ── Font-lock ─────────────────────────────────────────────────────────────
   `(font-lock-comment-face         ((t (:foreground ,fg-dim :slant italic))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,fg-dim))))
   `(font-lock-string-face          ((t (:foreground ,green))))
   `(font-lock-doc-face             ((t (:foreground ,fg-dim :slant italic))))
   `(font-lock-keyword-face         ((t (:foreground ,purple :weight bold))))
   `(font-lock-builtin-face         ((t (:foreground ,cyan))))
   `(font-lock-function-name-face   ((t (:foreground ,blue))))
   `(font-lock-variable-name-face   ((t (:foreground ,fg-main))))
   `(font-lock-type-face            ((t (:foreground ,cyan))))
   `(font-lock-constant-face        ((t (:foreground ,orange))))
   `(font-lock-warning-face         ((t (:foreground ,red :weight bold))))
   `(font-lock-negation-char-face   ((t (:foreground ,red))))
   `(font-lock-preprocessor-face    ((t (:foreground ,purple))))
   `(font-lock-regexp-grouping-construct ((t (:foreground ,cyan))))
   `(font-lock-regexp-grouping-backslash ((t (:foreground ,orange))))
   ;; ── Org ───────────────────────────────────────────────────────────────────
   `(org-level-1                    ((t (:foreground ,blue   :weight bold :height 1.15))))
   `(org-level-2                    ((t (:foreground ,amber  :weight bold :height 1.05))))
   `(org-level-3                    ((t (:foreground ,purple :weight semi-bold))))
   `(org-level-4                    ((t (:foreground ,cyan))))
   `(org-level-5                    ((t (:foreground ,green))))
   `(org-level-6                    ((t (:foreground ,orange))))
   `(org-block                      ((t (:background ,bg-dim :extend t))))
   `(org-block-begin-line           ((t (:background ,bg-dim :foreground ,fg-dim :extend t))))
   `(org-block-end-line             ((t (:background ,bg-dim :foreground ,fg-dim :extend t))))
   `(org-code                       ((t (:foreground ,green :background ,bg-dim))))
   `(org-verbatim                   ((t (:foreground ,cyan  :background ,bg-dim))))
   `(org-todo                       ((t (:foreground ,amber :weight bold))))
   `(org-done                       ((t (:foreground ,fg-dim :weight bold))))
   `(org-headline-done              ((t (:foreground ,fg-dim))))
   `(org-mode-line-clock            ((t (:foreground ,amber))))
   `(org-mode-line-clock-overrun    ((t (:foreground ,red :weight bold))))
   `(org-link                       ((t (:foreground ,blue :underline t))))
   `(org-date                       ((t (:foreground ,cyan :underline t))))
   `(org-tag                        ((t (:foreground ,fg-dim :weight bold))))
   `(org-special-keyword            ((t (:foreground ,fg-dim))))
   `(org-drawer                     ((t (:foreground ,fg-dim))))
   `(org-document-title             ((t (:foreground ,fg-main :weight bold :height 1.3))))
   `(org-document-info              ((t (:foreground ,fg-dim))))
   `(org-table                      ((t (:foreground ,fg-main))))
   `(org-formula                    ((t (:foreground ,orange))))
   ;; ── Orbit modeline faces ──────────────────────────────────────────────────
   `(orbit-modeline-evil-normal     ((t (:background ,amber   :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-insert     ((t (:background ,cyan    :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-visual     ((t (:background ,red     :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-replace    ((t (:background ,orange  :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-emacs      ((t (:background ,purple  :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-motion     ((t (:background ,blue    :foreground ,bg-main :weight bold))))
   `(orbit-modeline-context         ((t (:background ,bg-dim  :foreground ,fg-main))))
   `(orbit-modeline-context-edit    ((t (:background ,bg-dim  :foreground ,amber  :weight bold))))
   `(orbit-modeline-context-git     ((t (:background ,bg-dim  :foreground ,green  :weight bold))))
   `(orbit-modeline-context-files   ((t (:background ,bg-dim  :foreground ,blue   :weight bold))))
   `(orbit-modeline-context-notes   ((t (:background ,bg-dim  :foreground ,purple :weight bold))))
   `(orbit-modeline-context-roam    ((t (:background ,bg-dim  :foreground ,cyan   :weight bold))))
   `(orbit-modeline-context-scratch ((t (:background ,bg-dim  :foreground ,orange :weight bold))))
   `(orbit-modeline-buffer          ((t (:background ,bg-dim  :foreground ,fg-main :weight bold))))
   `(orbit-modeline-brand           ((t (:background ,amber   :foreground ,bg-main :weight bold))))
   `(orbit-modeline-separator       ((t (:background ,bg-dim  :foreground ,fg-dim))))
   `(orbit-modeline-state-modified  ((t (:background ,bg-dim  :foreground ,amber  :weight bold))))
   `(orbit-modeline-state-read-only ((t (:background ,bg-dim  :foreground ,red    :weight bold))))
   `(orbit-modeline-state-narrowed  ((t (:background ,bg-dim  :foreground ,purple :weight bold))))
   `(orbit-modeline-borrowed        ((t (:background ,bg-dim  :foreground ,cyan   :weight bold))))
   `(orbit-modeline-vc              ((t (:background ,bg-dim  :foreground ,green))))
   `(orbit-modeline-mode            ((t (:background ,bg-dim  :foreground ,fg-dim))))
   `(orbit-modeline-meta            ((t (:background ,bg-dim  :foreground ,fg-dim))))
   `(orbit-modeline-position        ((t (:background ,bg-dim  :foreground ,fg-main :weight bold))))
   `(orbit-modeline-right           ((t (:background ,bg-dim  :foreground ,fg-dim))))
   ;; ── Orbit header-line faces ───────────────────────────────────────────────
   `(orbit-header-context           ((t (:foreground ,amber   :weight bold :background ,bg-dark))))
   `(orbit-header-context-edit      ((t (:foreground ,amber   :weight bold :background ,bg-dark))))
   `(orbit-header-context-git       ((t (:foreground ,green   :weight bold :background ,bg-dark))))
   `(orbit-header-context-files     ((t (:foreground ,blue    :weight bold :background ,bg-dark))))
   `(orbit-header-context-notes     ((t (:foreground ,purple  :weight bold :background ,bg-dark))))
   `(orbit-header-context-roam      ((t (:foreground ,cyan    :weight bold :background ,bg-dark))))
   `(orbit-header-context-scratch   ((t (:foreground ,orange  :weight bold :background ,bg-dark))))
   `(orbit-header-sep               ((t (:foreground ,fg-dim  :background ,bg-dark))))
   `(orbit-header-path              ((t (:foreground ,fg-dim  :background ,bg-dark))))
   `(orbit-header-clock             ((t (:foreground ,amber   :slant italic :background ,bg-dark))))
   ;; ── Orbit menu faces ─────────────────────────────────────────────────────
   `(orbit-menu-strip               ((t (:inherit default :background ,bg-dark :foreground ,fg-dim :box nil))))
   `(orbit-menu-label               ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
   `(orbit-menu-label-active        ((t (:inherit default :background ,bg-hl   :foreground ,amber :weight bold))))
   `(orbit-menu-dropdown            ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
   `(orbit-menu-dropdown-title      ((t (:inherit default :background ,bg-dark :foreground ,amber :weight bold))))
   `(orbit-menu-dropdown-heading    ((t (:inherit default :background ,bg-dark :foreground ,blue :weight bold))))
   `(orbit-menu-dropdown-command    ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
   `(orbit-menu-dropdown-disabled   ((t (:inherit default :background ,bg-dark :foreground ,fg-dim))))
   ;; ── Orbit home faces ──────────────────────────────────────────────────────
   `(orbit-home-logo                ((t (:foreground ,amber   :weight bold))))
   `(orbit-home-tagline             ((t (:foreground ,fg-dim  :slant italic))))
   `(orbit-home-clock               ((t (:foreground ,amber))))
   `(orbit-home-section             ((t (:foreground ,fg-main :weight bold))))
   `(orbit-home-key                 ((t (:foreground ,amber   :weight bold))))
   `(orbit-home-project             ((t (:foreground ,fg-main))))
   `(orbit-home-path                ((t (:foreground ,fg-dim  :slant italic))))
   `(orbit-home-todo                ((t (:foreground ,fg-dim))))
   `(orbit-home-state-next          ((t (:foreground ,cyan    :weight bold))))
   `(orbit-home-state-in-progress   ((t (:foreground ,amber   :weight bold))))
   `(orbit-home-state-wait          ((t (:foreground ,orange  :weight bold))))
   ;; ── Diff-hl ───────────────────────────────────────────────────────────────
   `(diff-hl-insert                 ((t (:foreground ,green   :background ,bg-main))))
   `(diff-hl-change                 ((t (:foreground ,amber   :background ,bg-main))))
   `(diff-hl-delete                 ((t (:foreground ,red     :background ,bg-main))))
   ;; ── Magit ─────────────────────────────────────────────────────────────────
   `(magit-section-heading               ((t (:foreground ,amber :weight bold))))
   `(magit-section-heading-selection     ((t (:foreground ,orange :weight bold))))
   `(magit-branch-local                  ((t (:foreground ,blue))))
   `(magit-branch-remote                 ((t (:foreground ,cyan))))
   `(magit-branch-current                ((t (:foreground ,amber :weight bold))))
   `(magit-diff-added                    ((t (:background ,diff-add-bg :foreground ,green))))
   `(magit-diff-added-highlight          ((t (:background ,diff-add-hl :foreground ,green))))
   `(magit-diff-removed                  ((t (:background ,diff-rem-bg :foreground ,red))))
   `(magit-diff-removed-highlight        ((t (:background ,diff-rem-hl :foreground ,red))))
   `(magit-diff-context                  ((t (:background ,bg-main :foreground ,fg-dim))))
   `(magit-diff-context-highlight        ((t (:background ,bg-dim  :foreground ,fg-main))))
   `(magit-hash                          ((t (:foreground ,fg-dim))))
   `(magit-tag                           ((t (:foreground ,amber))))
   ;; ── Completion / Vertico / Corfu ──────────────────────────────────────────
   `(vertico-current                ((t (:background ,bg-hl :weight bold :extend t))))
   `(corfu-current                  ((t (:background ,bg-hl :weight bold))))
   `(corfu-border                   ((t (:background ,bg-dim))))
   `(corfu-bar                      ((t (:background ,amber))))
   `(corfu-annotations              ((t (:foreground ,fg-dim))))
   `(corfu-popupinfo                ((t (:background ,bg-dark :foreground ,fg-main))))
   `(completions-common-part        ((t (:foreground ,amber :weight bold))))
   `(completions-first-difference   ((t (:foreground ,blue  :weight bold))))
   ;; ── Which-key ─────────────────────────────────────────────────────────────
   `(which-key-key-face                  ((t (:foreground ,amber   :weight bold))))
   `(which-key-command-description-face  ((t (:foreground ,fg-main))))
   `(which-key-group-description-face    ((t (:foreground ,blue))))
   `(which-key-separator-face            ((t (:foreground ,fg-dim))))
   ;; ── Consult ───────────────────────────────────────────────────────────────
   `(consult-file                   ((t (:foreground ,blue))))
   `(consult-buffer                 ((t (:foreground ,fg-main))))))

(provide-theme 'orbit-dark)

;; ─── orbit-light ─────────────────────────────────────────────────────────────

(deftheme orbit-light "Orbit light theme — warm cream with amber accent.")

(let* ((bg-main     "#fdf6e3")
       (bg-dim      "#f5ede1")
       (bg-hl       "#eee8d5")
       (bg-inactive "#d3cbb8")
       (fg-main     "#362015")
       (fg-dim      "#8e908c")
       (amber       "#c68000")
       (blue        "#2b6cb0")
       (purple      "#7c3aed")
       (green       "#276749")
       (red         "#c0392b")
       (orange      "#d35400")
       (cyan        "#1a7490")
       (bg-dark     "#ede8d0")
       ;; Diff bg tints
       (diff-add-bg "#e8f5e9")
       (diff-add-hl "#c8e6c9")
       (diff-rem-bg "#fce4e4")
       (diff-rem-hl "#f8bbd0"))
  (custom-theme-set-faces
   'orbit-light
   ;; ── Core UI ──────────────────────────────────────────────────────────────
   `(default                        ((t (:background ,bg-main :foreground ,fg-main))))
   `(cursor                         ((t (:background ,amber))))
   `(fringe                         ((t (:background ,bg-main :foreground ,fg-dim))))
   `(region                         ((t (:background ,bg-hl :extend t))))
   `(highlight                      ((t (:background ,bg-hl))))
   `(hl-line                        ((t (:background ,bg-hl :extend t))))
   `(minibuffer-prompt              ((t (:foreground ,amber :weight bold))))
   `(isearch                        ((t (:background ,amber :foreground ,bg-main :weight bold))))
   `(isearch-fail                   ((t (:background ,red :foreground ,bg-main))))
   `(lazy-highlight                 ((t (:background ,bg-hl :foreground ,fg-main))))
   `(match                          ((t (:background ,bg-hl :foreground ,amber))))
   `(line-number                    ((t (:background ,bg-main :foreground ,fg-dim))))
   `(line-number-current-line       ((t (:background ,bg-main :foreground ,amber :weight bold))))
   `(mode-line                      ((t (:background ,bg-dim :foreground ,fg-main :box nil))))
   `(mode-line-inactive             ((t (:background ,bg-inactive :foreground ,fg-dim :box nil))))
   `(mode-line-buffer-id            ((t (:foreground ,fg-main :weight bold))))
   `(header-line                    ((t (:background ,bg-dark :foreground ,fg-dim :box nil :inherit nil))))
   `(vertical-border                ((t (:foreground ,bg-dim))))
   `(window-divider                 ((t (:foreground ,bg-dim))))
   `(window-divider-first-pixel     ((t (:foreground ,bg-dim))))
   `(window-divider-last-pixel      ((t (:foreground ,bg-dim))))
   `(fill-column-indicator          ((t (:foreground ,bg-hl))))
   `(link                           ((t (:foreground ,blue :underline t))))
   `(link-visited                   ((t (:foreground ,purple :underline t))))
   `(error                          ((t (:foreground ,red :weight bold))))
   `(warning                        ((t (:foreground ,orange :weight bold))))
   `(success                        ((t (:foreground ,green :weight bold))))
   `(shadow                         ((t (:foreground ,fg-dim))))
   `(secondary-selection            ((t (:background ,bg-hl))))
   `(mod-evil-pulse                 ((t (:background ,amber))))
   `(trailing-whitespace            ((t (:background ,red))))
   `(whitespace-tab                 ((t (:foreground ,bg-hl :background ,bg-main))))
   `(whitespace-trailing            ((t (:background ,red))))
   ;; ── Font-lock ─────────────────────────────────────────────────────────────
   `(font-lock-comment-face         ((t (:foreground ,fg-dim :slant italic))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,fg-dim))))
   `(font-lock-string-face          ((t (:foreground ,green))))
   `(font-lock-doc-face             ((t (:foreground ,fg-dim :slant italic))))
   `(font-lock-keyword-face         ((t (:foreground ,purple :weight bold))))
   `(font-lock-builtin-face         ((t (:foreground ,cyan))))
   `(font-lock-function-name-face   ((t (:foreground ,blue))))
   `(font-lock-variable-name-face   ((t (:foreground ,fg-main))))
   `(font-lock-type-face            ((t (:foreground ,cyan))))
   `(font-lock-constant-face        ((t (:foreground ,orange))))
   `(font-lock-warning-face         ((t (:foreground ,red :weight bold))))
   `(font-lock-negation-char-face   ((t (:foreground ,red))))
   `(font-lock-preprocessor-face    ((t (:foreground ,purple))))
   `(font-lock-regexp-grouping-construct ((t (:foreground ,cyan))))
   `(font-lock-regexp-grouping-backslash ((t (:foreground ,orange))))
   ;; ── Org ───────────────────────────────────────────────────────────────────
   `(org-level-1                    ((t (:foreground ,blue   :weight bold :height 1.15))))
   `(org-level-2                    ((t (:foreground ,amber  :weight bold :height 1.05))))
   `(org-level-3                    ((t (:foreground ,purple :weight semi-bold))))
   `(org-level-4                    ((t (:foreground ,cyan))))
   `(org-level-5                    ((t (:foreground ,green))))
   `(org-level-6                    ((t (:foreground ,orange))))
   `(org-block                      ((t (:background ,bg-dim :extend t))))
   `(org-block-begin-line           ((t (:background ,bg-dim :foreground ,fg-dim :extend t))))
   `(org-block-end-line             ((t (:background ,bg-dim :foreground ,fg-dim :extend t))))
   `(org-code                       ((t (:foreground ,green :background ,bg-dim))))
   `(org-verbatim                   ((t (:foreground ,cyan  :background ,bg-dim))))
   `(org-todo                       ((t (:foreground ,amber :weight bold))))
   `(org-done                       ((t (:foreground ,fg-dim :weight bold))))
   `(org-headline-done              ((t (:foreground ,fg-dim))))
   `(org-mode-line-clock            ((t (:foreground ,amber))))
   `(org-mode-line-clock-overrun    ((t (:foreground ,red :weight bold))))
   `(org-link                       ((t (:foreground ,blue :underline t))))
   `(org-date                       ((t (:foreground ,cyan :underline t))))
   `(org-tag                        ((t (:foreground ,fg-dim :weight bold))))
   `(org-special-keyword            ((t (:foreground ,fg-dim))))
   `(org-drawer                     ((t (:foreground ,fg-dim))))
   `(org-document-title             ((t (:foreground ,fg-main :weight bold :height 1.3))))
   `(org-document-info              ((t (:foreground ,fg-dim))))
   `(org-table                      ((t (:foreground ,fg-main))))
   `(org-formula                    ((t (:foreground ,orange))))
   ;; ── Orbit modeline faces ──────────────────────────────────────────────────
   `(orbit-modeline-evil-normal     ((t (:background ,amber   :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-insert     ((t (:background ,cyan    :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-visual     ((t (:background ,red     :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-replace    ((t (:background ,orange  :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-emacs      ((t (:background ,purple  :foreground ,bg-main :weight bold))))
   `(orbit-modeline-evil-motion     ((t (:background ,blue    :foreground ,bg-main :weight bold))))
   `(orbit-modeline-context         ((t (:background ,bg-dim  :foreground ,fg-main))))
   `(orbit-modeline-context-edit    ((t (:background ,bg-dim  :foreground ,amber  :weight bold))))
   `(orbit-modeline-context-git     ((t (:background ,bg-dim  :foreground ,green  :weight bold))))
   `(orbit-modeline-context-files   ((t (:background ,bg-dim  :foreground ,blue   :weight bold))))
   `(orbit-modeline-context-notes   ((t (:background ,bg-dim  :foreground ,purple :weight bold))))
   `(orbit-modeline-context-roam    ((t (:background ,bg-dim  :foreground ,cyan   :weight bold))))
   `(orbit-modeline-context-scratch ((t (:background ,bg-dim  :foreground ,orange :weight bold))))
   `(orbit-modeline-buffer          ((t (:background ,bg-dim  :foreground ,fg-main :weight bold))))
   `(orbit-modeline-brand           ((t (:background ,amber   :foreground ,bg-main :weight bold))))
   `(orbit-modeline-separator       ((t (:background ,bg-dim  :foreground ,fg-dim))))
   `(orbit-modeline-state-modified  ((t (:background ,bg-dim  :foreground ,amber  :weight bold))))
   `(orbit-modeline-state-read-only ((t (:background ,bg-dim  :foreground ,red    :weight bold))))
   `(orbit-modeline-state-narrowed  ((t (:background ,bg-dim  :foreground ,purple :weight bold))))
   `(orbit-modeline-borrowed        ((t (:background ,bg-dim  :foreground ,cyan   :weight bold))))
   `(orbit-modeline-vc              ((t (:background ,bg-dim  :foreground ,green))))
   `(orbit-modeline-mode            ((t (:background ,bg-dim  :foreground ,fg-dim))))
   `(orbit-modeline-meta            ((t (:background ,bg-dim  :foreground ,fg-dim))))
   `(orbit-modeline-position        ((t (:background ,bg-dim  :foreground ,fg-main :weight bold))))
   `(orbit-modeline-right           ((t (:background ,bg-dim  :foreground ,fg-dim))))
   ;; ── Orbit header-line faces ───────────────────────────────────────────────
   `(orbit-header-context           ((t (:foreground ,amber   :weight bold :background ,bg-dark))))
   `(orbit-header-context-edit      ((t (:foreground ,amber   :weight bold :background ,bg-dark))))
   `(orbit-header-context-git       ((t (:foreground ,green   :weight bold :background ,bg-dark))))
   `(orbit-header-context-files     ((t (:foreground ,blue    :weight bold :background ,bg-dark))))
   `(orbit-header-context-notes     ((t (:foreground ,purple  :weight bold :background ,bg-dark))))
   `(orbit-header-context-roam      ((t (:foreground ,cyan    :weight bold :background ,bg-dark))))
   `(orbit-header-context-scratch   ((t (:foreground ,orange  :weight bold :background ,bg-dark))))
   `(orbit-header-sep               ((t (:foreground ,fg-dim  :background ,bg-dark))))
   `(orbit-header-path              ((t (:foreground ,fg-dim  :background ,bg-dark))))
   `(orbit-header-clock             ((t (:foreground ,amber   :slant italic :background ,bg-dark))))
   ;; ── Orbit menu faces ─────────────────────────────────────────────────────
   `(orbit-menu-strip               ((t (:inherit default :background ,bg-dark :foreground ,fg-dim :box nil))))
   `(orbit-menu-label               ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
   `(orbit-menu-label-active        ((t (:inherit default :background ,bg-hl   :foreground ,amber :weight bold))))
   `(orbit-menu-dropdown            ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
   `(orbit-menu-dropdown-title      ((t (:inherit default :background ,bg-dark :foreground ,amber :weight bold))))
   `(orbit-menu-dropdown-heading    ((t (:inherit default :background ,bg-dark :foreground ,blue :weight bold))))
   `(orbit-menu-dropdown-command    ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
   `(orbit-menu-dropdown-disabled   ((t (:inherit default :background ,bg-dark :foreground ,fg-dim))))
   ;; ── Orbit home faces ──────────────────────────────────────────────────────
   `(orbit-home-logo                ((t (:foreground ,amber   :weight bold))))
   `(orbit-home-tagline             ((t (:foreground ,fg-dim  :slant italic))))
   `(orbit-home-clock               ((t (:foreground ,amber))))
   `(orbit-home-section             ((t (:foreground ,fg-main :weight bold))))
   `(orbit-home-key                 ((t (:foreground ,amber   :weight bold))))
   `(orbit-home-project             ((t (:foreground ,fg-main))))
   `(orbit-home-path                ((t (:foreground ,fg-dim  :slant italic))))
   `(orbit-home-todo                ((t (:foreground ,fg-dim))))
   `(orbit-home-state-next          ((t (:foreground ,cyan    :weight bold))))
   `(orbit-home-state-in-progress   ((t (:foreground ,amber   :weight bold))))
   `(orbit-home-state-wait          ((t (:foreground ,orange  :weight bold))))
   ;; ── Diff-hl ───────────────────────────────────────────────────────────────
   `(diff-hl-insert                 ((t (:foreground ,green  :background ,bg-main))))
   `(diff-hl-change                 ((t (:foreground ,amber  :background ,bg-main))))
   `(diff-hl-delete                 ((t (:foreground ,red    :background ,bg-main))))
   ;; ── Magit ─────────────────────────────────────────────────────────────────
   `(magit-section-heading               ((t (:foreground ,amber :weight bold))))
   `(magit-section-heading-selection     ((t (:foreground ,orange :weight bold))))
   `(magit-branch-local                  ((t (:foreground ,blue))))
   `(magit-branch-remote                 ((t (:foreground ,cyan))))
   `(magit-branch-current                ((t (:foreground ,amber :weight bold))))
   `(magit-diff-added                    ((t (:background ,diff-add-bg :foreground ,green))))
   `(magit-diff-added-highlight          ((t (:background ,diff-add-hl :foreground ,green))))
   `(magit-diff-removed                  ((t (:background ,diff-rem-bg :foreground ,red))))
   `(magit-diff-removed-highlight        ((t (:background ,diff-rem-hl :foreground ,red))))
   `(magit-diff-context                  ((t (:background ,bg-main :foreground ,fg-dim))))
   `(magit-diff-context-highlight        ((t (:background ,bg-dim  :foreground ,fg-main))))
   `(magit-hash                          ((t (:foreground ,fg-dim))))
   `(magit-tag                           ((t (:foreground ,amber))))
   ;; ── Completion / Vertico / Corfu ──────────────────────────────────────────
   `(vertico-current                ((t (:background ,bg-hl :weight bold :extend t))))
   `(corfu-current                  ((t (:background ,bg-hl :weight bold))))
   `(corfu-border                   ((t (:background ,bg-dim))))
   `(corfu-bar                      ((t (:background ,amber))))
   `(corfu-annotations              ((t (:foreground ,fg-dim))))
   `(corfu-popupinfo                ((t (:background ,bg-dark :foreground ,fg-main))))
   `(completions-common-part        ((t (:foreground ,amber :weight bold))))
   `(completions-first-difference   ((t (:foreground ,blue  :weight bold))))
   ;; ── Which-key ─────────────────────────────────────────────────────────────
   `(which-key-key-face                  ((t (:foreground ,amber   :weight bold))))
   `(which-key-command-description-face  ((t (:foreground ,fg-main))))
   `(which-key-group-description-face    ((t (:foreground ,blue))))
   `(which-key-separator-face            ((t (:foreground ,fg-dim))))
   ;; ── Consult ───────────────────────────────────────────────────────────────
   `(consult-file                   ((t (:foreground ,blue))))
   `(consult-buffer                 ((t (:foreground ,fg-main))))))

(provide-theme 'orbit-light)

;; ─── Retro Orbit palette themes ─────────────────────────────────────────────

(defun mod-theme--palette-get (palette key)
  "Return KEY from PALETTE."
  (plist-get palette key))

(defun mod-theme--define-palette-theme (theme description palette)
  "Define THEME with DESCRIPTION from a shared Orbit PALETTE."
  (custom-declare-theme
   theme
   (custom-make-theme-feature theme)
   description)
  (let* ((bg-main     (mod-theme--palette-get palette :bg-main))
         (bg-dim      (mod-theme--palette-get palette :bg-dim))
         (bg-hl       (mod-theme--palette-get palette :bg-hl))
         (bg-inactive (mod-theme--palette-get palette :bg-inactive))
         (fg-main     (mod-theme--palette-get palette :fg-main))
         (fg-dim      (mod-theme--palette-get palette :fg-dim))
         (amber       (mod-theme--palette-get palette :amber))
         (blue        (mod-theme--palette-get palette :blue))
         (purple      (mod-theme--palette-get palette :purple))
         (green       (mod-theme--palette-get palette :green))
         (red         (mod-theme--palette-get palette :red))
         (orange      (mod-theme--palette-get palette :orange))
         (cyan        (mod-theme--palette-get palette :cyan))
         (pulse       (or (mod-theme--palette-get palette :pulse) amber))
         (bg-dark     (mod-theme--palette-get palette :bg-dark))
         (diff-add-bg (mod-theme--palette-get palette :diff-add-bg))
         (diff-add-hl (mod-theme--palette-get palette :diff-add-hl))
         (diff-rem-bg (mod-theme--palette-get palette :diff-rem-bg))
         (diff-rem-hl (mod-theme--palette-get palette :diff-rem-hl)))
    (custom-theme-set-faces
     theme
     `(default                        ((t (:background ,bg-main :foreground ,fg-main))))
     `(cursor                         ((t (:background ,amber))))
     `(fringe                         ((t (:background ,bg-main :foreground ,fg-dim))))
     `(region                         ((t (:background ,bg-hl :extend t))))
     `(highlight                      ((t (:background ,bg-hl))))
     `(hl-line                        ((t (:background ,bg-hl :extend t))))
     `(minibuffer-prompt              ((t (:foreground ,amber :weight bold))))
     `(isearch                        ((t (:background ,amber :foreground ,bg-main :weight bold))))
     `(isearch-fail                   ((t (:background ,red :foreground ,bg-main))))
     `(lazy-highlight                 ((t (:background ,bg-hl :foreground ,fg-main))))
     `(match                          ((t (:background ,bg-hl :foreground ,amber))))
     `(line-number                    ((t (:background ,bg-main :foreground ,fg-dim))))
     `(line-number-current-line       ((t (:background ,bg-main :foreground ,amber :weight bold))))
     `(mode-line                      ((t (:background ,bg-dim :foreground ,fg-main :box nil))))
     `(mode-line-inactive             ((t (:background ,bg-inactive :foreground ,fg-dim :box nil))))
     `(mode-line-buffer-id            ((t (:foreground ,fg-main :weight bold))))
     `(header-line                    ((t (:background ,bg-dark :foreground ,fg-dim :box nil :inherit nil))))
     `(vertical-border                ((t (:foreground ,bg-dim))))
     `(window-divider                 ((t (:foreground ,bg-dim))))
     `(window-divider-first-pixel     ((t (:foreground ,bg-dim))))
     `(window-divider-last-pixel      ((t (:foreground ,bg-dim))))
     `(fill-column-indicator          ((t (:foreground ,bg-hl))))
     `(link                           ((t (:foreground ,blue :underline t))))
     `(link-visited                   ((t (:foreground ,purple :underline t))))
     `(error                          ((t (:foreground ,red :weight bold))))
     `(warning                        ((t (:foreground ,orange :weight bold))))
     `(success                        ((t (:foreground ,green :weight bold))))
     `(shadow                         ((t (:foreground ,fg-dim))))
     `(secondary-selection            ((t (:background ,bg-hl))))
     `(mod-evil-pulse                 ((t (:background ,pulse))))
     `(trailing-whitespace            ((t (:background ,red))))
     `(whitespace-tab                 ((t (:foreground ,bg-hl :background ,bg-main))))
     `(whitespace-trailing            ((t (:background ,red))))
     `(font-lock-comment-face         ((t (:foreground ,fg-dim :slant italic))))
     `(font-lock-comment-delimiter-face ((t (:foreground ,fg-dim))))
     `(font-lock-string-face          ((t (:foreground ,green))))
     `(font-lock-doc-face             ((t (:foreground ,fg-dim :slant italic))))
     `(font-lock-keyword-face         ((t (:foreground ,purple :weight bold))))
     `(font-lock-builtin-face         ((t (:foreground ,cyan))))
     `(font-lock-function-name-face   ((t (:foreground ,blue))))
     `(font-lock-variable-name-face   ((t (:foreground ,fg-main))))
     `(font-lock-type-face            ((t (:foreground ,cyan))))
     `(font-lock-constant-face        ((t (:foreground ,orange))))
     `(font-lock-warning-face         ((t (:foreground ,red :weight bold))))
     `(font-lock-negation-char-face   ((t (:foreground ,red))))
     `(font-lock-preprocessor-face    ((t (:foreground ,purple))))
     `(font-lock-regexp-grouping-construct ((t (:foreground ,cyan))))
     `(font-lock-regexp-grouping-backslash ((t (:foreground ,orange))))
     `(org-level-1                    ((t (:foreground ,blue   :weight bold :height 1.15))))
     `(org-level-2                    ((t (:foreground ,amber  :weight bold :height 1.05))))
     `(org-level-3                    ((t (:foreground ,purple :weight semi-bold))))
     `(org-level-4                    ((t (:foreground ,cyan))))
     `(org-level-5                    ((t (:foreground ,green))))
     `(org-level-6                    ((t (:foreground ,orange))))
     `(org-block                      ((t (:background ,bg-dim :extend t))))
     `(org-block-begin-line           ((t (:background ,bg-dim :foreground ,fg-dim :extend t))))
     `(org-block-end-line             ((t (:background ,bg-dim :foreground ,fg-dim :extend t))))
     `(org-code                       ((t (:foreground ,green :background ,bg-dim))))
     `(org-verbatim                   ((t (:foreground ,cyan  :background ,bg-dim))))
     `(org-todo                       ((t (:foreground ,amber :weight bold))))
     `(org-done                       ((t (:foreground ,fg-dim :weight bold))))
     `(org-headline-done              ((t (:foreground ,fg-dim))))
     `(org-mode-line-clock            ((t (:foreground ,amber))))
     `(org-mode-line-clock-overrun    ((t (:foreground ,red :weight bold))))
     `(org-link                       ((t (:foreground ,blue :underline t))))
     `(org-date                       ((t (:foreground ,cyan :underline t))))
     `(org-tag                        ((t (:foreground ,fg-dim :weight bold))))
     `(org-special-keyword            ((t (:foreground ,fg-dim))))
     `(org-drawer                     ((t (:foreground ,fg-dim))))
     `(org-document-title             ((t (:foreground ,fg-main :weight bold :height 1.3))))
     `(org-document-info              ((t (:foreground ,fg-dim))))
     `(org-table                      ((t (:foreground ,fg-main))))
     `(org-formula                    ((t (:foreground ,orange))))
     `(orbit-modeline-evil-normal     ((t (:background ,amber   :foreground ,bg-main :weight bold))))
     `(orbit-modeline-evil-insert     ((t (:background ,cyan    :foreground ,bg-main :weight bold))))
     `(orbit-modeline-evil-visual     ((t (:background ,red     :foreground ,bg-main :weight bold))))
     `(orbit-modeline-evil-replace    ((t (:background ,orange  :foreground ,bg-main :weight bold))))
     `(orbit-modeline-evil-emacs      ((t (:background ,purple  :foreground ,bg-main :weight bold))))
     `(orbit-modeline-evil-motion     ((t (:background ,blue    :foreground ,bg-main :weight bold))))
     `(orbit-modeline-context         ((t (:background ,bg-dim  :foreground ,fg-main))))
     `(orbit-modeline-context-edit    ((t (:background ,bg-dim  :foreground ,amber  :weight bold))))
     `(orbit-modeline-context-git     ((t (:background ,bg-dim  :foreground ,green  :weight bold))))
     `(orbit-modeline-context-files   ((t (:background ,bg-dim  :foreground ,blue   :weight bold))))
     `(orbit-modeline-context-notes   ((t (:background ,bg-dim  :foreground ,purple :weight bold))))
     `(orbit-modeline-context-roam    ((t (:background ,bg-dim  :foreground ,cyan   :weight bold))))
     `(orbit-modeline-context-scratch ((t (:background ,bg-dim  :foreground ,orange :weight bold))))
     `(orbit-modeline-buffer          ((t (:background ,bg-dim  :foreground ,fg-main :weight bold))))
     `(orbit-modeline-brand           ((t (:background ,amber   :foreground ,bg-main :weight bold))))
     `(orbit-modeline-separator       ((t (:background ,bg-dim  :foreground ,fg-dim))))
     `(orbit-modeline-state-modified  ((t (:background ,bg-dim  :foreground ,amber  :weight bold))))
     `(orbit-modeline-state-read-only ((t (:background ,bg-dim  :foreground ,red    :weight bold))))
     `(orbit-modeline-state-narrowed  ((t (:background ,bg-dim  :foreground ,purple :weight bold))))
     `(orbit-modeline-borrowed        ((t (:background ,bg-dim  :foreground ,cyan   :weight bold))))
     `(orbit-modeline-vc              ((t (:background ,bg-dim  :foreground ,green))))
     `(orbit-modeline-mode            ((t (:background ,bg-dim  :foreground ,fg-dim))))
     `(orbit-modeline-meta            ((t (:background ,bg-dim  :foreground ,fg-dim))))
     `(orbit-modeline-position        ((t (:background ,bg-dim  :foreground ,fg-main :weight bold))))
     `(orbit-modeline-right           ((t (:background ,bg-dim  :foreground ,fg-dim))))
     `(orbit-header-context           ((t (:foreground ,amber   :weight bold :background ,bg-dark))))
     `(orbit-header-context-edit      ((t (:foreground ,amber   :weight bold :background ,bg-dark))))
     `(orbit-header-context-git       ((t (:foreground ,green   :weight bold :background ,bg-dark))))
     `(orbit-header-context-files     ((t (:foreground ,blue    :weight bold :background ,bg-dark))))
     `(orbit-header-context-notes     ((t (:foreground ,purple  :weight bold :background ,bg-dark))))
     `(orbit-header-context-roam      ((t (:foreground ,cyan    :weight bold :background ,bg-dark))))
     `(orbit-header-context-scratch   ((t (:foreground ,orange  :weight bold :background ,bg-dark))))
     `(orbit-header-sep               ((t (:foreground ,fg-dim  :background ,bg-dark))))
     `(orbit-header-path              ((t (:foreground ,fg-dim  :background ,bg-dark))))
     `(orbit-header-clock             ((t (:foreground ,amber   :slant italic :background ,bg-dark))))
     `(orbit-menu-strip               ((t (:inherit default :background ,bg-dark :foreground ,fg-dim :box nil))))
     `(orbit-menu-label               ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
     `(orbit-menu-label-active        ((t (:inherit default :background ,bg-hl   :foreground ,amber :weight bold))))
     `(orbit-menu-dropdown            ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
     `(orbit-menu-dropdown-title      ((t (:inherit default :background ,bg-dark :foreground ,amber :weight bold))))
     `(orbit-menu-dropdown-heading    ((t (:inherit default :background ,bg-dark :foreground ,blue :weight bold))))
     `(orbit-menu-dropdown-command    ((t (:inherit default :background ,bg-dark :foreground ,fg-main))))
     `(orbit-menu-dropdown-disabled   ((t (:inherit default :background ,bg-dark :foreground ,fg-dim))))
     `(orbit-home-logo                ((t (:foreground ,amber   :weight bold))))
     `(orbit-home-tagline             ((t (:foreground ,fg-dim  :slant italic))))
     `(orbit-home-clock               ((t (:foreground ,amber))))
     `(orbit-home-section             ((t (:foreground ,fg-main :weight bold))))
     `(orbit-home-key                 ((t (:foreground ,amber   :weight bold))))
     `(orbit-home-project             ((t (:foreground ,fg-main))))
     `(orbit-home-path                ((t (:foreground ,fg-dim  :slant italic))))
     `(orbit-home-todo                ((t (:foreground ,fg-dim))))
     `(orbit-home-state-next          ((t (:foreground ,cyan    :weight bold))))
     `(orbit-home-state-in-progress   ((t (:foreground ,amber   :weight bold))))
     `(orbit-home-state-wait          ((t (:foreground ,orange  :weight bold))))
     `(diff-hl-insert                 ((t (:foreground ,green   :background ,bg-main))))
     `(diff-hl-change                 ((t (:foreground ,amber   :background ,bg-main))))
     `(diff-hl-delete                 ((t (:foreground ,red     :background ,bg-main))))
     `(magit-section-heading          ((t (:foreground ,amber :weight bold))))
     `(magit-section-heading-selection ((t (:foreground ,orange :weight bold))))
     `(magit-branch-local             ((t (:foreground ,blue))))
     `(magit-branch-remote            ((t (:foreground ,cyan))))
     `(magit-branch-current           ((t (:foreground ,amber :weight bold))))
     `(magit-diff-added               ((t (:background ,diff-add-bg :foreground ,green))))
     `(magit-diff-added-highlight     ((t (:background ,diff-add-hl :foreground ,green))))
     `(magit-diff-removed             ((t (:background ,diff-rem-bg :foreground ,red))))
     `(magit-diff-removed-highlight   ((t (:background ,diff-rem-hl :foreground ,red))))
     `(magit-diff-context             ((t (:background ,bg-main :foreground ,fg-dim))))
     `(magit-diff-context-highlight   ((t (:background ,bg-dim  :foreground ,fg-main))))
     `(magit-hash                     ((t (:foreground ,fg-dim))))
     `(magit-tag                      ((t (:foreground ,amber))))
     `(vertico-current                ((t (:background ,bg-hl :weight bold :extend t))))
     `(corfu-current                  ((t (:background ,bg-hl :weight bold))))
     `(corfu-border                   ((t (:background ,bg-dim))))
     `(corfu-bar                      ((t (:background ,amber))))
     `(corfu-annotations              ((t (:foreground ,fg-dim))))
     `(corfu-popupinfo                ((t (:background ,bg-dark :foreground ,fg-main))))
     `(completions-common-part        ((t (:foreground ,amber :weight bold))))
     `(completions-first-difference   ((t (:foreground ,blue  :weight bold))))
     `(which-key-key-face             ((t (:foreground ,amber   :weight bold))))
     `(which-key-command-description-face ((t (:foreground ,fg-main))))
     `(which-key-group-description-face ((t (:foreground ,blue))))
     `(which-key-separator-face       ((t (:foreground ,fg-dim))))
     `(consult-file                   ((t (:foreground ,blue))))
     `(consult-buffer                 ((t (:foreground ,fg-main))))))
  (provide-theme theme))

(mod-theme--define-palette-theme
 'orbit-retro-amber
 "Orbit retro amber — CRT amber glow on warm black."
 '(:bg-main "#120f0a" :bg-dim "#1f1a11" :bg-hl "#322713" :bg-inactive "#3a3020"
   :fg-main "#f4d58d" :fg-dim "#9c7f4f" :amber "#ffb454" :blue "#6fb1ff"
   :purple "#d08cff" :green "#a6e36f" :red "#ff6b6b" :orange "#ff8f40"
   :cyan "#6fd6d6" :pulse "#ffb454" :bg-dark "#0b0906" :diff-add-bg "#172514"
   :diff-add-hl "#20331b" :diff-rem-bg "#2a1512" :diff-rem-hl "#3a1c17"))

(mod-theme--define-palette-theme
 'orbit-retro-green
 "Orbit retro green — phosphor terminal green with Orbit accents."
 '(:bg-main "#07120a" :bg-dim "#0d1d11" :bg-hl "#15331b" :bg-inactive "#24402a"
   :fg-main "#b7ffbf" :fg-dim "#5f9c68" :amber "#d4d96a" :blue "#62b5ff"
   :purple "#c58cff" :green "#65ff7a" :red "#ff5f73" :orange "#ffb05c"
   :cyan "#5cffd6" :pulse "#65ff7a" :bg-dark "#030804" :diff-add-bg "#102413"
   :diff-add-hl "#17351b" :diff-rem-bg "#261012" :diff-rem-hl "#35161a"))

(mod-theme--define-palette-theme
 'orbit-retro-blue
 "Orbit retro blue — late-night terminal blue with restrained neon accents."
 '(:bg-main "#07111f" :bg-dim "#0d1b2f" :bg-hl "#142946" :bg-inactive "#223958"
   :fg-main "#b9d7ff" :fg-dim "#6f8eb8" :amber "#ffd166" :blue "#5cc8ff"
   :purple "#d29dff" :green "#80f0a0" :red "#ff6b8a" :orange "#ff9f5c"
   :cyan "#65f0ff" :pulse "#5cc8ff" :bg-dark "#040913" :diff-add-bg "#0e241b"
   :diff-add-hl "#143425" :diff-rem-bg "#28111b" :diff-rem-hl "#3a1726"))

(mod-theme--define-palette-theme
 'orbit-retro-temple
 "Orbit retro temple — bright primary-color computing on clean white."
 '(:bg-main "#ffffff" :bg-dim "#f0f0f0" :bg-hl "#e4e8ff" :bg-inactive "#d8d8d8"
   :fg-main "#0000aa" :fg-dim "#6060a0" :amber "#0000aa" :blue "#0000aa"
   :purple "#aa00aa" :green "#008000" :red "#aa0000" :orange "#aa5500"
   :cyan "#0088aa" :pulse "#0000ff" :bg-dark "#e8e8ff" :diff-add-bg "#e8ffe8"
   :diff-add-hl "#d0ffd0" :diff-rem-bg "#ffe8e8" :diff-rem-hl "#ffd0d0"))

(mod-theme--define-palette-theme
 'orbit-retro-paper
 "Orbit retro paper — dot-matrix paper with softened terminal colors."
 '(:bg-main "#fffbe8" :bg-dim "#f3ecd2" :bg-hl "#e8dfbd" :bg-inactive "#d8cfb0"
   :fg-main "#263238" :fg-dim "#7c7462" :amber "#9a6a00" :blue "#245c9a"
   :purple "#7357a6" :green "#3f7d35" :red "#a6362f" :orange "#b35c12"
   :cyan "#247c82" :pulse "#b88400" :bg-dark "#ede4c8" :diff-add-bg "#edf7df"
   :diff-add-hl "#d7edbf" :diff-rem-bg "#f9e3dd" :diff-rem-hl "#efc9c0"))

(mod-theme--define-palette-theme
 'orbit-retro-sky
 "Orbit retro sky — light blue workstation palette with crisp Orbit accents."
 '(:bg-main "#edf7ff" :bg-dim "#dcecf8" :bg-hl "#cfe3f4" :bg-inactive "#b8ccdc"
   :fg-main "#132f46" :fg-dim "#668398" :amber "#9b6500" :blue "#0069aa"
   :purple "#6d4fb3" :green "#247a50" :red "#b3344a" :orange "#b85f1d"
   :cyan "#007c8a" :pulse "#008fd1" :bg-dark "#d4e7f5" :diff-add-bg "#e0f3e8"
   :diff-add-hl "#c5e9d4" :diff-rem-bg "#f6e0e5" :diff-rem-hl "#edc3cc"))

;; ─── Font stack ──────────────────────────────────────────────────────────────

(defconst mod-theme-mono-font-candidates
  '("JetBrains Mono"
    "JetBrainsMonoNL Nerd Font Mono"
    "JetBrainsMono Nerd Font Mono"
    "Iosevka"
    "Cascadia Code"
    "IBM Plex Mono"
    "Source Code Pro"
    "Consolas"
    "Menlo")
  "Ordered list of preferred monospace font families.")

(defconst mod-theme-variable-font-candidates
  '("Inter"
    "SF Pro Text"
    "Segoe UI"
    "Source Sans Pro"
    "DejaVu Sans")
  "Ordered list of preferred variable-pitch font families.")

(defun mod-theme-apply-treemacs-faces ()
  "Align Treemacs faces with Orbit's visual language."
  (when (featurep 'treemacs-faces)
    (set-face-attribute 'treemacs-window-background-face nil
                        :inherit 'default
                        :background (face-background 'default nil t))
    (set-face-attribute 'treemacs-hl-line-face nil
                        :inherit 'hl-line
                        :background (face-background 'hl-line nil t))
    (set-face-attribute 'treemacs-root-face nil
                        :inherit 'orbit-header-context-files
                        :height 0.95
                        :weight 'bold)
    (set-face-attribute 'treemacs-directory-face nil
                        :inherit 'font-lock-keyword-face
                        :weight 'semi-bold)
    (set-face-attribute 'treemacs-directory-collapsed-face nil
                        :inherit 'shadow)
    (set-face-attribute 'treemacs-file-face nil
                        :inherit 'default)
    (set-face-attribute 'treemacs-tags-face nil
                        :inherit 'font-lock-function-name-face)
    (set-face-attribute 'treemacs-fringe-indicator-face nil
                        :inherit 'orbit-header-context-files)
    (set-face-attribute 'treemacs-git-modified-face nil
                        :inherit 'orbit-modeline-state-modified)
    (set-face-attribute 'treemacs-git-renamed-face nil
                        :inherit 'font-lock-keyword-face)
    (set-face-attribute 'treemacs-git-untracked-face nil
                        :inherit 'success)
    (set-face-attribute 'treemacs-git-added-face nil
                        :inherit 'success)
    (set-face-attribute 'treemacs-git-ignored-face nil
                        :inherit 'shadow)
    (set-face-attribute 'treemacs-git-conflict-face nil
                        :inherit 'error)
    (set-face-attribute 'treemacs-git-unmodified-face nil
                        :inherit 'default)))

(defun mod-theme--first-available-font (candidates)
  "Return the first font family in CANDIDATES that is installed, or nil."
  (when (display-graphic-p)
    (seq-find (lambda (f) (find-font (font-spec :family f))) candidates)))

(defvar mod-theme--current-font-preset nil
  "The currently active Orbit font preset name, or nil for direct settings.")

(defvar mod-theme--font-height-override nil
  "Runtime font height override set by Orbit font resize commands.")

(defun mod-theme--font-preset-name (preset)
  "Return the display name for font PRESET."
  (format "%s" (car preset)))

(defun mod-theme--font-preset (name)
  "Return the font preset named NAME."
  (alist-get name orbit-user-font-presets nil nil #'equal))

(defun mod-theme--font-settings ()
  "Return the active font settings plist."
  (or (and orbit-user-font-preset
           (mod-theme--font-preset orbit-user-font-preset))
      (list :family orbit-user-font-family
            :height orbit-user-font-height
            :weight orbit-user-font-weight
            :variable-family orbit-user-variable-pitch-font
            :variable-height orbit-user-variable-pitch-height
            :variable-weight orbit-user-variable-pitch-weight)))

(defun mod-theme--effective-font-settings ()
  "Return font settings including runtime overrides."
  (let ((settings (copy-sequence (mod-theme--font-settings))))
    (if mod-theme--font-height-override
        (plist-put settings :height mod-theme--font-height-override)
      settings)))

(defun mod-theme--current-font-height (&optional frame)
  "Return the current default face height for FRAME."
  (or mod-theme--font-height-override
      (plist-get (mod-theme--font-settings) :height)
      orbit-user-font-height
      (let ((height (face-attribute 'default :height (or frame (selected-frame)) 'default)))
        (when (and (integerp height)
                   (> height 20))
          height))
      140))

(defun mod-theme-apply-font-stack (&optional frame)
  "Apply the Orbit font stack to FRAME, respecting orbit-user-* overrides.
Falls back through `mod-theme-mono-font-candidates' when no override is set."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (let* ((settings (mod-theme--effective-font-settings))
             (mono-family (or (plist-get settings :family)
                              (mod-theme--first-available-font
                               mod-theme-mono-font-candidates)
                              "monospace"))
             (mono-height (or (plist-get settings :height) 'unspecified))
             (mono-weight (plist-get settings :weight))
             (vp-family   (or (plist-get settings :variable-family)
                              (mod-theme--first-available-font
                               mod-theme-variable-font-candidates)))
             (default-attrs `(:family ,mono-family
                              :height ,mono-height
                              ,@(when mono-weight `(:weight ,mono-weight))))
             (fixed-attrs   `(:family ,mono-family
                              :height 1.0
                              ,@(when mono-weight `(:weight ,mono-weight)))))
        (apply #'set-face-attribute 'default frame default-attrs)
        (apply #'set-face-attribute 'fixed-pitch frame fixed-attrs)
        (when vp-family
          (apply #'set-face-attribute 'variable-pitch frame
                 `(:family ,vp-family
                   :height ,(or (plist-get settings :variable-height) 1.0)
                   ,@(when (plist-get settings :variable-weight)
                       `(:weight ,(plist-get settings :variable-weight))))))))))

(defun mod-theme-select-font ()
  "Select an Orbit font preset with completion and apply it immediately."
  (interactive)
  (unless orbit-user-font-presets
    (user-error "No font presets configured in orbit-user-font-presets"))
  (let* ((preset-names (mapcar #'mod-theme--font-preset-name orbit-user-font-presets))
         (default (and orbit-user-font-preset (format "%s" orbit-user-font-preset)))
         (choice (completing-read "Orbit font: " preset-names nil t nil nil default)))
    (setq orbit-user-font-preset (car (assoc-string choice orbit-user-font-presets))
          mod-theme--font-height-override nil
          mod-theme--current-font-preset orbit-user-font-preset)
    (mod-theme-apply-font-stack)
    (force-mode-line-update t)
    (message "Font: %s" choice)))

(defun mod-theme-adjust-font-height (delta)
  "Adjust the current Orbit font height by DELTA."
  (interactive "nFont height delta: ")
  (let* ((current (mod-theme--current-font-height))
         (next (max 60 (+ current delta))))
    (setq mod-theme--font-height-override next)
    (mod-theme-apply-font-stack)
    (force-mode-line-update t)
    (message "Font height: %s" next)))

(defun mod-theme-increase-font-height ()
  "Increase the current Orbit font height."
  (interactive)
  (mod-theme-adjust-font-height (or orbit-user-font-resize-step 10)))

(defun mod-theme-decrease-font-height ()
  "Decrease the current Orbit font height."
  (interactive)
  (mod-theme-adjust-font-height (- (or orbit-user-font-resize-step 10))))

;; ─── Theme management ────────────────────────────────────────────────────────

(defvar mod-theme--current nil
  "The currently active Orbit theme symbol.")

(defconst mod-theme-themes
  '(orbit-dark
    orbit-light
    orbit-retro-amber
    orbit-retro-green
    orbit-retro-blue
    orbit-retro-temple
    orbit-retro-paper
    orbit-retro-sky)
  "Available Orbit themes.")

(defun mod-theme--known-theme-p (theme)
  "Return non-nil when THEME is a known Orbit theme."
  (memq theme mod-theme-themes))

(defun mod-theme-load (theme &optional apply-fonts)
  "Load THEME, disabling any other active theme.
When APPLY-FONTS is non-nil, also apply the font stack immediately.
During startup this is deferred to `window-setup-hook' to avoid blocking on
Windows (where `find-font' scans the system font list synchronously)."
  (let ((theme (if (mod-theme--known-theme-p theme)
                   theme
                 'orbit-dark)))
    (mapc #'disable-theme custom-enabled-themes)
    (enable-theme theme)
    (setq mod-theme--current theme)
    (mod-theme-apply-treemacs-faces)
    (when apply-fonts
      (mod-theme-apply-font-stack))
    (force-mode-line-update t)))

(defun mod-theme-select ()
  "Select an Orbit theme with completion."
  (interactive)
  (let* ((theme-names (mapcar #'symbol-name mod-theme-themes))
         (default (symbol-name (or mod-theme--current orbit-user-orbit-theme 'orbit-dark)))
         (choice (completing-read "Orbit theme: " theme-names nil t nil nil default)))
    (mod-theme-load (intern choice) 'apply-fonts)
    (message "Theme: %s" mod-theme--current)))

(defalias 'mod-theme-toggle #'mod-theme-select)

;;; Re-apply font stack when a new GUI frame is created (e.g. emacsclient --create-frame).
(add-hook 'after-make-frame-functions #'mod-theme-apply-font-stack)
(with-eval-after-load 'treemacs-faces
  (mod-theme-apply-treemacs-faces))

;; Apply the initial theme now (all Orbit themes are already defined above).
;; Font stack is NOT applied here — deferred below to avoid blocking on Windows.
(mod-theme-load (or orbit-user-orbit-theme 'orbit-dark))

;; Defer font stack application until after the first frame is fully ready.
;; This prevents `find-font' from blocking the GUI on Windows during startup.
(add-hook 'window-setup-hook #'mod-theme-apply-font-stack)

(provide 'mod-theme)

;;; mod-theme.el ends here
