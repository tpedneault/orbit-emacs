;;; mod-git.el --- Git foundation -*- lexical-binding: t; -*-

;; Magit requires a newer `transient' than the one available in this Emacs.
(use-package transient
  :ensure t
  :commands (transient-define-prefix))

(use-package magit
  :ensure (:fetcher github
           :repo "magit/magit"
           :depth 1
           :main-file "lisp/magit.el"
           :files ("lisp/*.el"
                   "docs/magit.texi"
                   "docs/AUTHORS.md"
                   "LICENSE"
                   ("git-hooks" "git-hooks/*")))
  :commands (magit-status magit-log-current magit-blame-addition))

(defun mod-git-status ()
  "Open Magit status for the current repository."
  (interactive)
  (call-interactively #'magit-status))

(defun mod-git-log ()
  "Open a compact Magit log entry point for the current repository."
  (interactive)
  (call-interactively #'magit-log-current))

(defun mod-git-blame ()
  "Start Magit blame for the current file."
  (interactive)
  (call-interactively #'magit-blame-addition))

(provide 'mod-git)

;;; mod-git.el ends here
