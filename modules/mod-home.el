;;; mod-home.el --- Home dashboard -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep the startup home surface lightweight while still giving orbit-emacs a
;; dedicated landing page.

;;; Code:

(declare-function dashboard-open "dashboard")
(declare-function dashboard-refresh-buffer "dashboard")

(defconst mod-home-buffer-name "*dashboard*"
  "Buffer used as the orbit home surface.")

(use-package dashboard
  :ensure t
  :demand t
  :config
  (setq dashboard-banner-logo-title "orbit-emacs"
        dashboard-startup-banner 'official
        dashboard-set-heading-icons nil
        dashboard-set-file-icons nil
        dashboard-center-content t
        dashboard-items '((recents  . 8)
                          (projects . 5)
                          (bookmarks . 5)))
  (dashboard-setup-startup-hook))

(defun mod-home-open ()
  "Open or refresh the orbit home dashboard."
  (interactive)
  (if (get-buffer mod-home-buffer-name)
      (progn
        (switch-to-buffer mod-home-buffer-name)
        (dashboard-refresh-buffer))
    (dashboard-open)))

(setq initial-buffer-choice #'mod-home-open)

(provide 'mod-home)

;;; mod-home.el ends here
