;;; init.el --- Main entry point -*- lexical-binding: t; -*-

(let ((config-dir (file-name-directory (or load-file-name buffer-file-name))))
  (add-to-list 'load-path (expand-file-name "modules" config-dir)))

(require 'mod-core)
(require 'mod-home)
(require 'mod-ui)
(require 'mod-dired)
(require 'mod-evil)
(require 'mod-git)
(require 'mod-utility)
(require 'mod-keys)
(require 'mod-completion)
(require 'mod-org)
(require 'mod-project)
(require 'mod-tcl)
(require 'mod-context)
(require 'mod-session)

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(org-agenda-files
   '("/Users/thomas/org/roam/school/20260415142708-econ201.org"
     "/Users/thomas/org/school/school.org"
     "/Users/thomas/org/inbox.org" "/Users/thomas/org/journal.org"
     "/Users/thomas/org/notes.org" "/Users/thomas/org/projects.org"
     "/Users/thomas/org/tasks.org" "/Users/thomas/org/todo.org")))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
