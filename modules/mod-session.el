;;; mod-session.el --- Manual session foundation -*- lexical-binding: t; -*-

(declare-function orbit-context-session-load "orbit-context-session" (session-file))
(declare-function orbit-context-session-save "orbit-context-session" (session-file))

(defconst mod-session-file
  (expand-file-name "session-state" mod-core-var-directory)
  "Default file for manually saving and loading Perspective session state.")

(defun mod-session-save ()
  "Manually save the current Perspective session state."
  (interactive)
  (orbit-context-session-save mod-session-file))

(defun mod-session-load ()
  "Manually load Perspective session state from the default session file."
  (interactive)
  (unless (file-exists-p mod-session-file)
    (user-error "Session file not found: %s" mod-session-file))
  (orbit-context-session-load mod-session-file))

(provide 'mod-session)

;;; mod-session.el ends here
