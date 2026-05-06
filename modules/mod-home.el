;;; mod-home.el --- Minimal orbit home buffer -*- lexical-binding: t; -*-

;;; Commentary:
;; Keeps the startup "home" behavior intentionally simple.
;; The previous dashboard package integration is disabled to avoid extra GUI
;; startup work and package-related startup failures.

;;; Code:

(defconst mod-home-buffer-name "*scratch*"
  "Buffer used as the orbit home surface.")

(defun mod-home-open ()
  "Open the minimal orbit home buffer."
  (interactive)
  (switch-to-buffer (get-buffer-create mod-home-buffer-name)))

(setq initial-buffer-choice #'mod-home-open)

(provide 'mod-home)

;;; mod-home.el ends here
