;;; mod-keys.el --- Leader key foundation -*- lexical-binding: t; -*-

(require 'project)

(defun mod-keys--context-placeholder (action)
  "Report that ACTION is reserved for the future context system."
  (interactive)
  (user-error "Context %s is not implemented yet" action))

(defun mod-keys-context-switch ()
  "Placeholder for context switching."
  (interactive)
  (mod-keys--context-placeholder "switch"))

(defun mod-keys-context-new ()
  "Placeholder for creating a new context."
  (interactive)
  (mod-keys--context-placeholder "new"))

(defun mod-keys-context-delete ()
  "Placeholder for deleting a context."
  (interactive)
  (mod-keys--context-placeholder "delete"))

(defun mod-keys-context-rename ()
  "Placeholder for renaming a context."
  (interactive)
  (mod-keys--context-placeholder "rename"))

(defun mod-keys-context-previous ()
  "Placeholder for moving to the previous context."
  (interactive)
  (mod-keys--context-placeholder "previous"))

(defun mod-keys-context-next ()
  "Placeholder for moving to the next context."
  (interactive)
  (mod-keys--context-placeholder "next"))

(use-package which-key
  :ensure t
  :demand t
  :config
  (which-key-mode 1))

(use-package general
  :ensure (:fetcher github :repo "noctuid/general.el" :main-file "general.el")
  :demand t
  :config
  (define-prefix-command 'mod-keys-local-leader-map)

  (general-create-definer mod-keys-leader-def
    :states '(normal visual motion emacs)
    :keymaps 'override
    :prefix "SPC")

  (general-create-definer mod-keys-local-leader-def
    :states '(normal visual motion emacs)
    :keymaps 'mod-keys-local-leader-map)

  (mod-keys-leader-def
    "" '(:ignore t :which-key "leader")
    "f" '(:ignore t :which-key "files")
    "f f" '(find-file :which-key "find file")
    "f s" '(save-buffer :which-key "save")
    "b" '(:ignore t :which-key "buffers")
    "b b" '(switch-to-buffer :which-key "switch buffer")
    "b d" '(kill-current-buffer :which-key "kill buffer")
    "p" '(:ignore t :which-key "projects")
    "p p" '(project-switch-project :which-key "switch project")
    "p f" '(project-find-file :which-key "find file")
    "w" '(:ignore t :which-key "windows")
    "w w" '(other-window :which-key "other window")
    "w d" '(delete-window :which-key "delete window")
    "w o" '(delete-other-windows :which-key "only window")
    "w s" '(split-window-below :which-key "split below")
    "w v" '(split-window-right :which-key "split right")
    "g" '(:ignore t :which-key "git")
    "g s" '(vc-dir :which-key "status")
    "m" '(mod-keys-local-leader-map :which-key "local")
    "o" '(:ignore t :which-key "utility")
    "n" '(:ignore t :which-key "notes")
    "x" '(:ignore t :which-key "contexts")
    "x x" '(mod-keys-context-switch :which-key "switch")
    "x n" '(mod-keys-context-new :which-key "new")
    "x d" '(mod-keys-context-delete :which-key "delete")
    "x r" '(mod-keys-context-rename :which-key "rename")
    "x [" '(mod-keys-context-previous :which-key "previous")
    "x ]" '(mod-keys-context-next :which-key "next")
    "t" '(:ignore t :which-key "toggles")
    "q" '(:ignore t :which-key "quit")
    "q q" '(save-buffers-kill-terminal :which-key "quit"))

  (mod-keys-local-leader-def
    "" '(:ignore t :which-key "local")))

(provide 'mod-keys)

;;; mod-keys.el ends here
