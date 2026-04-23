;;; mod-session.el --- Manual session foundation -*- lexical-binding: t; -*-

(defconst mod-session-file
  (expand-file-name "session-state" mod-core-var-directory)
  "Default file for manually saving and loading Perspective session state.")

(defun mod-session-save ()
  "Manually save the current Perspective session state."
  (interactive)
  (persp-state-save mod-session-file))

(defun mod-session-load ()
  "Manually load Perspective session state from the default session file."
  (interactive)
  (unless (file-exists-p mod-session-file)
    (user-error "Session file not found: %s" mod-session-file))
  (persp-state-load mod-session-file))

(provide 'mod-session)

;;; mod-session.el ends here
