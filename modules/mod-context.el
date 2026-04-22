;;; mod-context.el --- Context foundation -*- lexical-binding: t; -*-

(use-package perspective
  :ensure t
  :demand t
  :init
  (setq persp-mode-prefix-key nil
        persp-suppress-no-prefix-key-warning t
        persp-sort 'created
        persp-show-modestring nil
        persp-state-default-file nil)
  :config
  (persp-mode 1))

(defun mod-context--deferred-placeholder (action)
  "Report that context ACTION is reserved for a later phase."
  (interactive)
  (user-error "Context %s is not implemented yet" action))

(defun mod-context-switch ()
  "Switch to an existing context or create one by name."
  (interactive)
  (call-interactively #'persp-switch))

(defun mod-context-new ()
  "Create and switch to a new blank context."
  (interactive)
  (let ((name (read-string "New context name: ")))
    (when (string-empty-p name)
      (user-error "Context name cannot be empty"))
    (when (gethash name (perspectives-hash))
      (user-error "Context already exists: %s" name))
    (persp-switch name)
    ;; Start a new context from a blank scratch-like workspace.
    (persp-switch-to-scratch-buffer)))

(defun mod-context-delete ()
  "Delete an existing context."
  (interactive)
  (call-interactively #'persp-kill))

(defun mod-context-rename ()
  "Rename the current context."
  (interactive)
  (call-interactively #'persp-rename))

(defun mod-context-previous ()
  "Switch to the previous context."
  (interactive)
  (persp-prev))

(defun mod-context-next ()
  "Switch to the next context."
  (interactive)
  (persp-next))

(defun mod-context-git ()
  "Deferred placeholder for context git action."
  (interactive)
  (mod-context--deferred-placeholder "git"))

(defun mod-context-files ()
  "Deferred placeholder for context files action."
  (interactive)
  (mod-context--deferred-placeholder "files"))

(defun mod-context-notes ()
  "Deferred placeholder for context notes action."
  (interactive)
  (mod-context--deferred-placeholder "notes"))

(defun mod-context-agenda ()
  "Deferred placeholder for context agenda action."
  (interactive)
  (mod-context--deferred-placeholder "agenda"))

(defun mod-context-scratch ()
  "Deferred placeholder for context scratch action."
  (interactive)
  (mod-context--deferred-placeholder "scratch"))

(provide 'mod-context)

;;; mod-context.el ends here
