;;; mod-home.el --- Orbit home screen via emacs-dashboard -*- lexical-binding: t; -*-

;;; Commentary:
;; Configures the `dashboard' package as the orbit-emacs home screen.
;; Projects open in the orbit edit context instead of the default switch fn.

;;; Code:

(require 'cl-lib)

(declare-function dashboard-open              "dashboard")
(declare-function dashboard-refresh-buffer    "dashboard")
(declare-function dashboard-setup-startup-hook "dashboard")
(declare-function mod-context-open-project-editor "mod-context")

;;; ─── Entry point ──────────────────────────────────────────────────────────────

(defun mod-home-open ()
  "Open the Orbit home dashboard."
  (interactive)
  (cond
   ((fboundp 'dashboard-open)           (dashboard-open))
   ((fboundp 'dashboard-refresh-buffer) (dashboard-refresh-buffer))
   (t (message "orbit-home: dashboard package is not loaded"))))

;;; ─── Project context integration ─────────────────────────────────────────────

(defun mod-home--open-project-in-context (root)
  "Open project ROOT in the orbit edit context rather than the default handler."
  (require 'mod-context)
  (mod-context-open-project-editor
   (list :root root
         :name (file-name-nondirectory (directory-file-name root)))))

;;; ─── Dashboard configuration ──────────────────────────────────────────────────

(use-package dashboard
  :ensure t
  :demand t

  :init
  ;; ── Banner ────────────────────────────────────────────────────────────────────
  (setq dashboard-startup-banner
        (let ((f (expand-file-name "assets/orbit-banner.txt" user-emacs-directory)))
          (if (file-exists-p f) f 'ascii))

        dashboard-banner-logo-title
        "orbit-emacs  ·  Modal, context-based Emacs for focused work."

        ;; ── Layout ───────────────────────────────────────────────────────────────
        ;; Extra blank lines in the startup list give each section room to breathe.
        dashboard-startupify-list
        '(dashboard-insert-banner
          dashboard-insert-newline
          dashboard-insert-banner-title
          dashboard-insert-newline
          dashboard-insert-init-info
          dashboard-insert-newline
          dashboard-insert-newline
          dashboard-insert-items
          dashboard-insert-newline
          dashboard-insert-footer)

        ;; One blank line between sections inside the items block.
        dashboard-page-separator "\n\n"

        dashboard-center-content              t
        dashboard-vertically-center-content   nil

        ;; ── Section names ─────────────────────────────────────────────────────────
        ;; Clean headings: no trailing colons, orbit ◈ prefix.
        dashboard-item-names
        '(("Recent Files:"     . "◈  Recent Files")
          ("Projects:"         . "◈  Projects")
          ("Agenda for today:" . "◈  Today")
          ("Bookmarks:"        . "◈  Bookmarks"))

        ;; ── Sections and their sizes ───────────────────────────────────────────────
        dashboard-projects-backend 'project-el
        dashboard-items            '((projects . 7)
                                     (agenda   . 5)
                                     (recents  . 5))

        ;; Show "project-name  ~/path/to/project" with alignment.
        dashboard-projects-show-base 'align

        ;; ── Orbit context integration ──────────────────────────────────────────────
        ;; Open projects in an orbit edit/‹name› context instead of project.el default.
        dashboard-projects-switch-function #'mod-home--open-project-in-context

        ;; ── Agenda ───────────────────────────────────────────────────────────────────
        dashboard-week-agenda               nil
        dashboard-agenda-time-string-format "%m/%d"
        dashboard-agenda-prefix-format      " %i %-10:c %t "

        ;; ── Misc ──────────────────────────────────────────────────────────────────────
        ;; No icon packages required.
        dashboard-display-icons-p     nil
        dashboard-set-heading-icons   nil
        dashboard-set-file-icons      nil
        dashboard-set-navigator       nil
        dashboard-set-init-info       t

        dashboard-footer-messages
        '("SPC h h  →  return here  ·  SPC t T  →  toggle theme  ·  SPC x e  →  edit context"))

  :config
  ;; ── Face aliases ──────────────────────────────────────────────────────────────
  ;; Map dashboard faces to orbit equivalents so the theme controls all colour.
  (with-eval-after-load 'mod-theme
    (custom-set-faces
     '(dashboard-banner-logo-title ((t (:inherit orbit-home-tagline :weight bold))))
     '(dashboard-heading            ((t (:inherit orbit-home-section))))
     '(dashboard-items-face         ((t (:inherit orbit-home-project))))
     '(dashboard-no-items-face      ((t (:inherit orbit-home-todo))))
     '(dashboard-footer-face        ((t (:inherit orbit-home-todo))))
     '(dashboard-text-banner        ((t (:inherit orbit-home-logo))))))

  ;; ── Buffer chrome ─────────────────────────────────────────────────────────────
  ;; No modeline or header line inside the dashboard; let it fill the window.
  (add-hook 'dashboard-mode-hook
            (lambda ()
              (setq-local mode-line-format   nil
                          header-line-format nil
                          cursor-type        nil)))

  ;; ── Startup ───────────────────────────────────────────────────────────────────
  ;; Sets initial-buffer-choice; ignored by Emacs when files are on the command line.
  (dashboard-setup-startup-hook))

(provide 'mod-home)

;;; mod-home.el ends here
