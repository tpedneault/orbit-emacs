;;; mod-keys.el --- Leader key foundation -*- lexical-binding: t; -*-

(require 'project)

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
    "f f" '(find-file :which-key "find file")
    "f s" '(save-buffer :which-key "save")
    "b" '(:ignore t :which-key "buffers")
    "b b" '(switch-to-buffer :which-key "switch buffer")
    "b d" '(kill-current-buffer :which-key "kill buffer")
    "p" '(:ignore t :which-key "projects")
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
    "g" '(:ignore t :which-key "git")
    "g g" '(mod-git-status :which-key "status")
    "g l" '(mod-git-log :which-key "log")
    "g b" '(mod-git-blame :which-key "blame")
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
