;;; mod-theme.el --- Orbit visual identity -*- lexical-binding: t; -*-

;;; Commentary:
;; Defines the orbit-dark and orbit-light custom themes, a recommended
;; font stack with graceful fallback, and the `mod-theme-load' /
;; `mod-theme-toggle' commands.
;;
;; Load order: mod-core → mod-theme → mod-home → mod-ui
;; This ensures themes are active before mod-ui applies the modeline.

;;; Code:

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
(defface orbit-modeline-buffer
  '((t (:inherit mode-line :weight bold))) "Buffer name segment of the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-mode
  '((t (:inherit mode-line))) "Major mode segment of the orbit modeline." :group 'orbit-faces)
(defface orbit-modeline-right
  '((t (:inherit mode-line))) "Right-hand segment of the orbit modeline." :group 'orbit-faces)

;; Header line
(defface orbit-header-context
  '((t (:inherit header-line :weight bold))) "Context name in the orbit header line." :group 'orbit-faces)
(defface orbit-header-sep
  '((t (:inherit header-line))) "Separator glyph in the orbit header line." :group 'orbit-faces)
(defface orbit-header-path
  '((t (:inherit header-line))) "File path in the orbit header line." :group 'orbit-faces)
(defface orbit-header-clock
  '((t (:inherit header-line :slant italic))) "Clock segment in the orbit header line." :group 'orbit-faces)

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
   `(orbit-modeline-buffer          ((t (:background ,bg-dim  :foreground ,fg-main :weight bold))))
   `(orbit-modeline-mode            ((t (:background ,bg-dim  :foreground ,fg-dim))))
   `(orbit-modeline-right           ((t (:background ,bg-dim  :foreground ,fg-dim))))
   ;; ── Orbit header-line faces ───────────────────────────────────────────────
   `(orbit-header-context           ((t (:foreground ,amber   :weight bold :background ,bg-dark))))
   `(orbit-header-sep               ((t (:foreground ,fg-dim  :background ,bg-dark))))
   `(orbit-header-path              ((t (:foreground ,fg-dim  :background ,bg-dark))))
   `(orbit-header-clock             ((t (:foreground ,amber   :slant italic :background ,bg-dark))))
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
   `(orbit-modeline-buffer          ((t (:background ,bg-dim  :foreground ,fg-main :weight bold))))
   `(orbit-modeline-mode            ((t (:background ,bg-dim  :foreground ,fg-dim))))
   `(orbit-modeline-right           ((t (:background ,bg-dim  :foreground ,fg-dim))))
   ;; ── Orbit header-line faces ───────────────────────────────────────────────
   `(orbit-header-context           ((t (:foreground ,amber   :weight bold :background ,bg-dark))))
   `(orbit-header-sep               ((t (:foreground ,fg-dim  :background ,bg-dark))))
   `(orbit-header-path              ((t (:foreground ,fg-dim  :background ,bg-dark))))
   `(orbit-header-clock             ((t (:foreground ,amber   :slant italic :background ,bg-dark))))
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

(defun mod-theme--first-available-font (candidates)
  "Return the first font family in CANDIDATES that is installed, or nil."
  (when (display-graphic-p)
    (seq-find (lambda (f) (find-font (font-spec :family f))) candidates)))

(defun mod-theme-apply-font-stack (&optional frame)
  "Apply the Orbit font stack to FRAME, respecting orbit-user-* overrides.
Falls back through `mod-theme-mono-font-candidates' when no override is set."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (let* ((mono-family (or orbit-user-font-family
                              (mod-theme--first-available-font
                               mod-theme-mono-font-candidates)
                              "monospace"))
             (mono-height (or orbit-user-font-height 'unspecified))
             (mono-weight orbit-user-font-weight)
             (vp-family   (or orbit-user-variable-pitch-font
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
                   :height ,(or orbit-user-variable-pitch-height 1.0)
                   ,@(when orbit-user-variable-pitch-weight
                       `(:weight ,orbit-user-variable-pitch-weight)))))))))

;; ─── Theme management ────────────────────────────────────────────────────────

(defvar mod-theme--current nil
  "The currently active Orbit theme symbol (orbit-dark or orbit-light).")

(defun mod-theme-load (theme &optional apply-fonts)
  "Load THEME (orbit-dark or orbit-light), disabling any other active theme.
When APPLY-FONTS is non-nil, also apply the font stack immediately.
During startup this is deferred to `window-setup-hook' to avoid blocking on
Windows (where `find-font' scans the system font list synchronously)."
  (mapc #'disable-theme custom-enabled-themes)
  (enable-theme theme)
  (setq mod-theme--current theme)
  (when apply-fonts
    (mod-theme-apply-font-stack))
  (force-mode-line-update t))

(defun mod-theme-toggle ()
  "Toggle between orbit-dark and orbit-light."
  (interactive)
  (mod-theme-load
   (if (eq mod-theme--current 'orbit-dark) 'orbit-light 'orbit-dark)
   'apply-fonts)
  (message "Theme: %s" mod-theme--current))

;;; Re-apply font stack when a new GUI frame is created (e.g. emacsclient --create-frame).
(add-hook 'after-make-frame-functions #'mod-theme-apply-font-stack)

;; Apply the initial theme now (both defthemes are already defined above).
;; Font stack is NOT applied here — deferred below to avoid blocking on Windows.
(mod-theme-load (or orbit-user-orbit-theme 'orbit-dark))

;; Defer font stack application until after the first frame is fully ready.
;; This prevents `find-font' from blocking the GUI on Windows during startup.
(add-hook 'window-setup-hook #'mod-theme-apply-font-stack)

(provide 'mod-theme)

;;; mod-theme.el ends here
