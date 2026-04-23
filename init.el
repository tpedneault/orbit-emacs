;;; init.el --- Main entry point -*- lexical-binding: t; -*-

(let ((config-dir (file-name-directory (or load-file-name buffer-file-name))))
  (add-to-list 'load-path (expand-file-name "modules" config-dir)))

(require 'mod-core)
(require 'mod-ui)
(require 'mod-dired)
(require 'mod-evil)
(require 'mod-git)
(require 'mod-keys)
(require 'mod-completion)
(require 'mod-project)
(require 'mod-context)
(require 'mod-session)

;;; init.el ends here
