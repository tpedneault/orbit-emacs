;;; mod-home.el --- Orbit home screen via emacs-dashboard -*- lexical-binding: t; -*-

;;; Commentary:
;; Configures the `dashboard' package as the orbit-emacs home screen.
;; Projects open in the orbit edit context instead of the default switch fn.

;;; Code:

(require 'cl-lib)

(declare-function dashboard-open "dashboard")
(declare-function dashboard-refresh-buffer "dashboard")
(declare-function dashboard-setup-startup-hook "dashboard")
(declare-function mod-context-open-project-editor "mod-context")

(defconst mod-home-config-directory
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Root directory for this Emacs configuration.")

(defconst mod-home-buffer-name "*dashboard*"
  "Buffer used as the orbit home surface.")

(defun mod-home-open ()
  "Open the Orbit home dashboard."
  (interactive)
  (cond
   ((get-buffer mod-home-buffer-name)
    (switch-to-buffer mod-home-buffer-name)
    (dashboard-refresh-buffer))
   ((fboundp 'dashboard-open)
    (dashboard-open))
   (t
    (message "orbit-home: dashboard package is not loaded"))))

(defun mod-home--open-project-in-context (root)
  "Open project ROOT in the orbit edit context rather than the default handler."
  (require 'mod-context)
  (mod-context-open-project-editor
   (list :root root
         :name (file-name-nondirectory (directory-file-name root)))))

(use-package dashboard
  :ensure t
  :demand t
  :init
  (setq dashboard-startup-banner
        (let ((file (expand-file-name "assets/orbit-banner.txt" mod-home-config-directory)))
          (if (file-exists-p file) file 'ascii))
        dashboard-banner-logo-title
        "orbit-emacs  ·  Modal, context-based Emacs for focused work."
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
        dashboard-page-separator "\n\n"
        dashboard-center-content t
        dashboard-vertically-center-content nil
        dashboard-item-names
        '(("Recent Files:"     . "◈  Recent Files")
          ("Projects:"         . "◈  Projects")
          ("Agenda for today:" . "◈  Today")
          ("Bookmarks:"        . "◈  Bookmarks"))
        dashboard-projects-backend 'project-el
        dashboard-items '((projects . 7)
                          (agenda   . 5)
                          (recents  . 5))
        dashboard-projects-show-base 'align
        dashboard-projects-switch-function #'mod-home--open-project-in-context
        dashboard-week-agenda nil
        dashboard-agenda-time-string-format "%m/%d"
        dashboard-agenda-prefix-format " %i %-10:c %t "
        dashboard-display-icons-p nil
        dashboard-set-heading-icons nil
        dashboard-set-file-icons nil
        dashboard-set-navigator nil
        dashboard-set-init-info t
        dashboard-footer-messages
        '("SPC h h  →  return here  ·  SPC t T  →  toggle theme  ·  SPC x e  →  edit context"))
  :config
  (with-eval-after-load 'mod-theme
    (custom-set-faces
     '(dashboard-banner-logo-title ((t (:inherit orbit-home-tagline :weight bold))))
     '(dashboard-heading ((t (:inherit orbit-home-section))))
     '(dashboard-items-face ((t (:inherit orbit-home-project))))
     '(dashboard-no-items-face ((t (:inherit orbit-home-todo))))
     '(dashboard-footer-face ((t (:inherit orbit-home-todo))))
     '(dashboard-text-banner ((t (:inherit orbit-home-logo))))))
  (add-hook 'dashboard-mode-hook
            (lambda ()
              (setq-local mode-line-format nil
                          header-line-format nil
                          cursor-type nil)))
  (dashboard-setup-startup-hook))

(setq initial-buffer-choice #'mod-home-open)

(provide 'mod-home)

;;; mod-home.el ends here
