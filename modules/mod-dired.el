;;; mod-dired.el --- Dired foundation -*- lexical-binding: t; -*-

(require 'dired)
(require 'dired-x)

(setq delete-by-moving-to-trash t
      dired-dwim-target t
      dired-recursive-copies 'always
      dired-recursive-deletes 'top)

(let ((gls (executable-find "gls"))
      (ls (executable-find "ls")))
  (setq insert-directory-program (or gls ls))
  (setq dired-listing-switches
        (if gls
            "-alh --group-directories-first"
          "-alh")))

(put 'dired-find-alternate-file 'disabled nil)

(defun mod-dired-here ()
  "Open Dired in the current default directory."
  (interactive)
  (dired default-directory))

(defun mod-dired-jump ()
  "Jump to a Dired buffer for the current file or directory."
  (interactive)
  (dired-jump))

(add-hook 'dired-mode-hook #'hl-line-mode)
(add-hook 'dired-mode-hook #'auto-revert-mode)

(provide 'mod-dired)

;;; mod-dired.el ends here
