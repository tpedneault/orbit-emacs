;;; mod-keys.el --- Leader key foundation -*- lexical-binding: t; -*-

(require 'project)

(defconst mod-keys-config-directory
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Root directory for this Emacs configuration.")

(defun mod-keys-open-init-file ()
  "Open init.el for this configuration."
  (interactive)
  (find-file (expand-file-name "init.el" mod-keys-config-directory)))

(defun mod-keys-open-early-init-file ()
  "Open early-init.el for this configuration."
  (interactive)
  (find-file (expand-file-name "early-init.el" mod-keys-config-directory)))

(defun mod-keys-open-modules-directory ()
  "Open the modules directory for this configuration."
  (interactive)
  (dired (expand-file-name "modules/" mod-keys-config-directory)))

(defun mod-keys-open-agents-file ()
  "Open AGENTS.md for this configuration."
  (interactive)
  (find-file (expand-file-name "AGENTS.md" mod-keys-config-directory)))

(defun mod-keys-open-docs-directory ()
  "Open the docs directory for this configuration."
  (interactive)
  (dired (expand-file-name "docs/" mod-keys-config-directory)))

(defun mod-keys-reload-config ()
  "Reload the Orbit Emacs configuration."
  (interactive)
  (load-file (expand-file-name "init.el" mod-keys-config-directory))
  (message "Reloaded orbit-emacs config"))

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
    "SPC" '(consult-buffer :which-key "buffer")
    "." '(project-find-file :which-key "project file")
    "/" '(mod-project-search :which-key "project search")
    ":" '(execute-extended-command :which-key "M-x")
    "," '(mod-keys-local-leader-map :which-key "local")
    "f" '(:ignore t :which-key "files")
    "f c" '(:ignore t :which-key "config")
    "f c s" '(:ignore t :which-key "snippets")
    "f c i" '(mod-keys-open-init-file :which-key "init.el")
    "f c e" '(mod-keys-open-early-init-file :which-key "early-init.el")
    "f c m" '(mod-keys-open-modules-directory :which-key "modules/")
    "f c a" '(mod-keys-open-agents-file :which-key "AGENTS.md")
    "f c d" '(mod-keys-open-docs-directory :which-key "docs/")
    "f c r" '(mod-keys-reload-config :which-key "reload")
    "f c s e" '(yas-visit-snippet-file :which-key "edit snippet")
    "f c s n" '(yas-new-snippet :which-key "new snippet")
    "f c s r" '(yas-reload-all :which-key "reload snippets")
    "f f" '(find-file :which-key "find file")
    "f r" '(recentf-open-files :which-key "recent")
    "f s" '(save-buffer :which-key "save")
    "b" '(:ignore t :which-key "buffers")
    "b b" '(switch-to-buffer :which-key "switch buffer")
    "b d" '(kill-current-buffer :which-key "kill buffer")
    "b r" '(revert-buffer :which-key "revert")
    "h" '(:ignore t :which-key "help")
    "h k" '(describe-key :which-key "describe key")
    "h f" '(describe-function :which-key "describe function")
    "h m" '(describe-mode :which-key "describe mode")
    "h v" '(describe-variable :which-key "describe variable")
    "p" '(:ignore t :which-key "projects")
    "p d" '(mod-project-forget :which-key "forget")
    "p p" '(project-switch-project :which-key "switch project")
    "p f" '(project-find-file :which-key "find file")
    "p s" '(mod-project-search :which-key "search")
    "w" '(:ignore t :which-key "windows")
    "w w" '(other-window :which-key "other window")
    "w h" '(windmove-left :which-key "left")
    "w j" '(windmove-down :which-key "down")
    "w k" '(windmove-up :which-key "up")
    "w l" '(windmove-right :which-key "right")
    "w d" '(delete-window :which-key "delete window")
    "w o" '(delete-other-windows :which-key "only window")
    "w s" '(split-window-below :which-key "split below")
    "w v" '(split-window-right :which-key "split right")
    "w u" '(winner-undo :which-key "undo")
    "w U" '(winner-redo :which-key "redo")
    "g" '(:ignore t :which-key "git")
    "g g" '(mod-git-status :which-key "status")
    "g l" '(mod-git-log :which-key "log")
    "g b" '(mod-git-blame :which-key "blame")
    "i" '(:ignore t :which-key "insert")
    "i s" '(yas-insert-snippet :which-key "snippet")
    "m" '(mod-keys-local-leader-map :which-key "local")
    "o" '(:ignore t :which-key "utility")
    "o o" '(mod-utility-toggle :which-key "toggle")
    "o s" '(mod-utility-shell :which-key "shell")
    "o m" '(mod-utility-messages :which-key "messages")
    "o h" '(mod-utility-help :which-key "help")
    "o c" '(mod-utility-compilation :which-key "compilation")
    "n" '(:ignore t :which-key "notes")
    "n n" '(mod-org-open-notes :which-key "notes")
    "n a" '(mod-org-open-agenda :which-key "agenda")
    "n c" '(mod-org-capture :which-key "capture")
    "n t" '(mod-org-capture-inbox-task :which-key "inbox task")
    "n j" '(mod-org-capture-journal :which-key "journal")
    "n N" '(mod-org-capture-note :which-key "note")
    "x" '(:ignore t :which-key "contexts")
    "x x" '(mod-context-switch :which-key "switch")
    "x n" '(mod-context-new :which-key "new")
    "x d" '(mod-context-delete :which-key "delete")
    "x r" '(mod-context-rename :which-key "rename")
    "x [" '(mod-context-previous :which-key "previous")
    "x ]" '(mod-context-next :which-key "next")
    "x e" '(mod-context-editor :which-key "edit")
    "x g" '(mod-context-git :which-key "git")
    "x f" '(mod-context-files :which-key "files")
    "x o" '(mod-context-notes :which-key "notes")
    "x a" '(mod-context-agenda :which-key "agenda")
    "x s" '(mod-context-scratch :which-key "scratch")
    "t" '(:ignore t :which-key "toggles")
    "q" '(:ignore t :which-key "quit")
    "q s" '(mod-session-save :which-key "save session")
    "q l" '(mod-session-load :which-key "load session")
    "q q" '(save-buffers-kill-terminal :which-key "quit"))

  (mod-keys-local-leader-def
    "" '(:ignore t :which-key "local"))

  (with-eval-after-load 'org
    (general-define-key
     :states '(normal visual motion emacs)
     :keymaps 'org-mode-map
     :prefix "SPC m"
     "t" '(org-todo :which-key "todo")
     "s" '(org-schedule :which-key "schedule")
     "d" '(org-deadline :which-key "deadline")
     "r" '(org-refile :which-key "refile")
     "a" '(org-archive-subtree :which-key "archive")
     "p" '(org-priority :which-key "priority")))

  (with-eval-after-load 'tcl
    (general-define-key
     :states '(normal visual motion emacs)
     :keymaps 'tcl-mode-map
     :prefix "SPC m"
     "l" '(mod-tcl-lint-file :which-key "lint")
     "f" '(mod-tcl-format-file :which-key "format")
     "g" '(mod-tcl-find-tag :which-key "goto tag")
     "r" '(mod-tcl-rebuild-tags :which-key "rebuild TAGS")
     "e" '(mod-tcl-show-output :which-key "tool output")))

  (with-eval-after-load 'org-agenda
    (define-key org-agenda-mode-map (kbd "j") #'org-agenda-next-line)
    (define-key org-agenda-mode-map (kbd "k") #'org-agenda-previous-line)
    (define-key org-agenda-mode-map (kbd "RET") #'mod-org-agenda-visit)
    (when (fboundp 'evil-define-key)
      (evil-define-key '(normal motion emacs) org-agenda-mode-map
        (kbd "j") #'org-agenda-next-line
        (kbd "k") #'org-agenda-previous-line
        (kbd "RET") #'mod-org-agenda-visit))
    (general-define-key
     :states '(normal motion emacs)
     :keymaps 'org-agenda-mode-map
     :prefix "SPC m"
     "t" '(org-agenda-todo :which-key "todo")
     "s" '(org-agenda-schedule :which-key "schedule")
     "d" '(org-agenda-deadline :which-key "deadline")
     "r" '(org-agenda-refile :which-key "refile")
     "a" '(org-agenda-archive :which-key "archive")
     "v" '(mod-org-agenda-visit :which-key "visit"))))

(provide 'mod-keys)

;;; mod-keys.el ends here
