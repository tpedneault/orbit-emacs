;;; mod-project.el --- Project foundation -*- lexical-binding: t; -*-

(require 'project)

(declare-function consult-ripgrep "consult")

(defun mod-project-current ()
  "Return the current project or signal a user-facing error."
  (or (project-current)
      (user-error "Not in a project")))

(defun mod-project-root ()
  "Return the root directory of the current project."
  (project-root (mod-project-current)))

(defun mod-project-search ()
  "Search the current project with `consult-ripgrep'."
  (interactive)
  (consult-ripgrep (mod-project-root)))

(setq project-switch-commands
      '((project-find-file "Find file")
        (mod-project-search "Search")
        (project-dired "Dired")))

(provide 'mod-project)

;;; mod-project.el ends here
