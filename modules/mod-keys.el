;;; mod-keys.el --- Leader key foundation -*- lexical-binding: t; -*-

(require 'easymenu)
(require 'project)

(declare-function mod-core-menu-bar-enabled-p "mod-core")
(declare-function mod-core-vim-profile-p "mod-core")
(declare-function orbit-context-agenda "orbit-context")
(declare-function orbit-context-buffers "orbit-context")
(declare-function orbit-context-borrow-buffer "orbit-context")
(declare-function orbit-context-borrow-file "orbit-context")
(declare-function orbit-context-cleanup "orbit-context")
(declare-function orbit-context-delete "orbit-context")
(declare-function orbit-context-dispatch "orbit-context")
(declare-function orbit-context-editor "orbit-context")
(declare-function orbit-context-files "orbit-context")
(declare-function orbit-context-forget-buffer "orbit-context")
(declare-function orbit-context-git "orbit-context")
(declare-function orbit-context-move-buffer "orbit-context")
(declare-function orbit-context-new "orbit-context")
(declare-function orbit-context-next "orbit-context")
(declare-function orbit-context-notes "orbit-context")
(declare-function orbit-context-open-path "orbit-context")
(declare-function orbit-context-previous "orbit-context")
(declare-function orbit-context-project-suite "orbit-context")
(declare-function orbit-context-related "orbit-context")
(declare-function orbit-context-rename "orbit-context")
(declare-function orbit-context-scratch "orbit-context")
(declare-function orbit-context-switch "orbit-context")
(declare-function orbit-context-unborrow-buffer "orbit-context")
(declare-function mod-core-copy-absolute-file-path "mod-core")
(declare-function mod-core-copy-directory-path "mod-core")
(declare-function mod-core-copy-project-relative-file-path "mod-core")
(declare-function mod-core-duplicate-line-or-region "mod-core")
(declare-function mod-core-move-line-or-region-down "mod-core")
(declare-function mod-core-move-line-or-region-up "mod-core")
(declare-function mod-core-open-at-point "mod-core")
(declare-function mod-core-recentf-open "mod-core")
(declare-function mod-dired-project-sidebar-toggle "mod-dired")
(declare-function mod-git-find-file-from-revision "mod-git")
(declare-function mod-git-log-file "mod-git")
(declare-function mod-git-stage-file "mod-git")
(declare-function mod-git-unstage-file "mod-git")
(declare-function git-timemachine "git-timemachine")
(declare-function forge-list-pullreqs "forge-list")
(declare-function magit-dispatch "magit-transient")
(declare-function magit-file-dispatch "magit-transient")
(declare-function magit-diff "magit-diff")
(declare-function magit-file-stage "magit-files")
(declare-function magit-file-unstage "magit-files")
(declare-function diff-hl-next-hunk "diff-hl")
(declare-function diff-hl-previous-hunk "diff-hl")
(declare-function diff-hl-revert-hunk "diff-hl")
(declare-function org-roam-node-find "org-roam")
(declare-function org-roam-node-insert "org-roam")
(declare-function org-roam-buffer-toggle "org-roam")
(declare-function org-roam-capture "org-roam")
(declare-function org-roam-db-sync "org-roam-db")
(declare-function org-roam-dailies-goto-today "org-roam-dailies")
(declare-function org-roam-dailies-find-date "org-roam-dailies")
(declare-function mod-org-attach-file "mod-org")
(declare-function mod-org-attachment-directory "mod-org")
(declare-function mod-org-capture-evidence "mod-org")
(declare-function mod-org-capture-investigation "mod-org")
(declare-function mod-org-capture-jira-follow-up "mod-org")
(declare-function mod-org-capture-linked-task "mod-org")
(declare-function mod-org-capture-meeting-action "mod-org")
(declare-function mod-org-insert-attached-image "mod-org")
(declare-function mod-org-insert-heading-link "mod-org")
(declare-function mod-org-insert-node-link "mod-org")
(declare-function mod-org-open-link-at-point "mod-org")
(declare-function mod-org-toggle-emphasis-markers "mod-org")
(declare-function mod-org-toggle-inline-images "mod-org")
(declare-function mod-org-toggle-pretty-view "mod-org")
(declare-function mod-org-toggle-property-drawers "mod-org")
(declare-function mod-jira-open-issue "mod-jira")
(declare-function mod-jira-add-comment "mod-jira")
(declare-function mod-jira-import-issue "mod-jira")
(declare-function mod-jira-log-work "mod-jira")
(declare-function mod-jira-log-work-manual "mod-jira")
(declare-function mod-jira-open-file "mod-jira")
(declare-function mod-jira-transition-issue "mod-jira")
(declare-function mod-jira-refresh-issue "mod-jira")
(declare-function mod-jira-sync "mod-jira")
(declare-function mod-python-debug-file "mod-python")
(declare-function mod-python-eglot "mod-python")
(declare-function mod-python-eglot-reconnect "mod-python")
(declare-function mod-python-debug-restart "mod-python")
(declare-function mod-python-format-buffer "mod-python")
(declare-function mod-python-run-file "mod-python")
(declare-function mod-python-run-module "mod-python")
(declare-function mod-python-show-docs "mod-python")
(declare-function dape-breakpoint-expression "dape")
(declare-function dape-breakpoint-function "dape")
(declare-function dape-breakpoint-log "dape")
(declare-function dape-breakpoint-remove-all "dape")
(declare-function dape-breakpoint-remove-at-point "dape")
(declare-function dape-breakpoint-toggle "dape")
(declare-function dape-continue "dape")
(declare-function dape-info "dape")
(declare-function dape-kill "dape")
(declare-function dape-next "dape")
(declare-function dape-pause "dape")
(declare-function dape-repl "dape")
(declare-function dape-restart "dape")
(declare-function dape-step-in "dape")
(declare-function dape-step-out "dape")
(declare-function dape-watch-dwim "dape")
(declare-function markdown-preview "markdown-mode")
(declare-function markdown-export "markdown-mode")
(declare-function markdown-toggle-gfm-checkbox "markdown-mode")
(declare-function markdown-insert-image "markdown-mode")
(declare-function markdown-insert-link "markdown-mode")
(declare-function mod-home-open "mod-home")
(declare-function mod-theme-select "mod-theme")
(declare-function mod-theme-select-font "mod-theme")
(declare-function mod-theme-decrease-font-height "mod-theme")
(declare-function mod-theme-increase-font-height "mod-theme")
(declare-function mod-shell-open "mod-shell")
(declare-function mod-shell-new "mod-shell")
(declare-function mod-project-add "mod-project")
(declare-function mod-project-replace "mod-project")
(declare-function mod-search-buffer "mod-search")
(declare-function mod-search-directory "mod-search")
(declare-function mod-search-project "mod-search")
(declare-function mod-search-project-files "mod-search")
(declare-function mod-search-project-replace-all "mod-search")
(declare-function mod-search-project-replace-query "mod-search")
(declare-function mod-search-buffer-at-point "mod-search")
(declare-function mod-search-project-at-point "mod-search")
(declare-function er/expand-region "expand-region")
(declare-function consult-imenu "consult-imenu")
(declare-function consult-imenu-multi "consult-imenu" (&optional query))
(declare-function consult-line-multi "consult" (query &optional initial))
(declare-function consult-mark "consult" (&optional markers))
(declare-function consult-outline "consult" (&optional level))
(declare-function evil-show-jumps "evil-jumps")
(declare-function mod-mermaid-preview "mod-mermaid")
(declare-function mod-mermaid-auto-preview-mode "mod-mermaid")
(declare-function mod-mermaid-insert-flowchart "mod-mermaid")
(declare-function mod-mermaid-insert-sequence "mod-mermaid")
(declare-function mod-mermaid-insert-state "mod-mermaid")
(declare-function mod-mermaid-insert-timeline "mod-mermaid")
(declare-function mermaid-compile-buffer "mermaid-mode")
(declare-function mermaid-open-browser "mermaid-mode")
(declare-function mod-mib-compare-table "mod-mib")
(declare-function mod-mib-edit-field "mod-mib")
(declare-function mod-mib-index-status "mod-mib")
(declare-function mod-mib-insert-telecommand "mod-mib")
(declare-function mod-mib-jump-column "mod-mib")
(declare-function mod-mib-lookup-telecommand "mod-mib")
(declare-function mod-mib-lookup-tm-packet "mod-mib")
(declare-function mod-mib-lookup-tm-parameter "mod-mib")
(declare-function mod-mib-next-field "mod-mib")
(declare-function mod-mib-next-row "mod-mib")
(declare-function mod-mib-open-detail-source "mod-mib")
(declare-function mod-mib-open-or-create-table "mod-mib")
(declare-function mod-mib-open-table "mod-mib")
(declare-function mod-mib-open-table-other-root "mod-mib")
(declare-function mod-mib-previous-field "mod-mib")
(declare-function mod-mib-previous-row "mod-mib")
(declare-function mod-mib-realign "mod-mib")
(declare-function mod-mib-refresh-index "mod-mib")
(declare-function mod-mib-switch-root "mod-mib")
(declare-function mod-mib-toggle-column-header "mod-mib")
(declare-function org-babel-execute-src-block "ob")
(declare-function mod-org-backtab-dwim "mod-org")
(declare-function mod-org-table-align "mod-org")
(declare-function mod-org-table-create-or-convert-from-region "mod-org")
(declare-function mod-org-table-delete-column "mod-org")
(declare-function mod-org-table-insert-column "mod-org")
(declare-function mod-org-table-insert-row "mod-org")
(declare-function mod-org-table-kill-row "mod-org")
(declare-function mod-org-table-next-row "mod-org")
(declare-function mod-org-table-recalculate "mod-org")
(declare-function mod-org-tab-dwim "mod-org")
(declare-function mod-tcl-ait-jump "mod-tcl")

(defconst mod-keys-config-directory
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Root directory for this Emacs configuration.")

(defun mod-keys-open-init-file ()
  "Open init.el for this configuration."
  (interactive)
  (orbit-context-open-path (expand-file-name "init.el" mod-keys-config-directory)))

(defun mod-keys-open-early-init-file ()
  "Open early-init.el for this configuration."
  (interactive)
  (orbit-context-open-path (expand-file-name "early-init.el" mod-keys-config-directory)))

(defun mod-keys-open-modules-directory ()
  "Open the modules directory for this configuration."
  (interactive)
  (dired (expand-file-name "modules/" mod-keys-config-directory)))

(defun mod-keys-open-agents-file ()
  "Open AGENTS.md for this configuration."
  (interactive)
  (orbit-context-open-path (expand-file-name "AGENTS.md" mod-keys-config-directory)))

(defun mod-keys-open-docs-directory ()
  "Open the docs directory for this configuration."
  (interactive)
  (dired (expand-file-name "docs/" mod-keys-config-directory)))

(defun mod-keys-open-user-config-file ()
  "Open the user-local orbit-emacs config.el."
  (interactive)
  (orbit-context-open-path mod-core-user-config-file))

(defun mod-keys-open-user-directory ()
  "Open the user-local orbit-emacs directory."
  (interactive)
  (dired mod-core-user-directory))

(defun mod-keys-open-user-snippets-directory ()
  "Open the user-local orbit-emacs snippets directory."
  (interactive)
  (dired mod-core-user-snippets-directory))

(defun mod-keys-open-docs-manual ()
  "Open the Org documentation manual for this configuration."
  (interactive)
  (let ((manual-file (expand-file-name "docs/manual.org" mod-keys-config-directory)))
    (orbit-context-open-path manual-file)
    (when (and buffer-file-name
               (file-equal-p buffer-file-name manual-file))
      (read-only-mode 1)
      (view-mode 1))))

(defun mod-keys-reload-config ()
  "Reload the Orbit Emacs configuration."
  (interactive)
  (load-file (expand-file-name "init.el" mod-keys-config-directory))
  (message "Reloaded orbit-emacs config"))

(defun mod-keys-find-project-file ()
  "Find a file in the current project."
  (interactive)
  (if (project-current nil)
      (call-interactively #'project-find-file)
    (user-error "Not in a project")))

(defun mod-keys-show-jumps ()
  "Show jump history using Evil when available, or fall back to marks."
  (interactive)
  (if (fboundp 'evil-show-jumps)
      (call-interactively #'evil-show-jumps)
    (call-interactively #'consult-mark)))

(defun mod-keys--mode-local-prefix ()
  "Return the active mode-local Orbit prefix."
  (if (mod-core-vim-profile-p) "SPC m" "C-; m"))

(defun mod-keys--hook-for-keymap (keymap)
  "Return the mode hook symbol that conventionally owns KEYMAP."
  (let ((name (symbol-name keymap)))
    (when (string-suffix-p "-map" name)
      (intern (concat (substring name 0 (- (length name) 4)) "-hook")))))

(defun mod-keys--mode-local-hooks (keymaps)
  "Return mode hooks corresponding to KEYMAPS."
  (delq nil
        (mapcar #'mod-keys--hook-for-keymap
                (if (listp keymaps) keymaps (list keymaps)))))

(defun mod-keys--define-mode-local (keymaps &rest bindings)
  "Define Orbit mode-local BINDINGS in KEYMAPS for the active profile."
  (if (mod-core-vim-profile-p)
      (dolist (hook (mod-keys--mode-local-hooks keymaps))
        (add-hook hook
                  (lambda ()
                    (apply #'general-define-key
                           :states '(normal visual motion)
                           :keymaps 'local
                           :prefix (mod-keys--mode-local-prefix)
                           bindings))))
    (apply #'general-define-key
           :keymaps keymaps
           :prefix (mod-keys--mode-local-prefix)
           bindings)))

(defun mod-keys--define-motion-mode-local (keymaps &rest bindings)
  "Define Orbit mode-local motion BINDINGS in KEYMAPS for the active profile."
  (if (mod-core-vim-profile-p)
      (dolist (hook (mod-keys--mode-local-hooks keymaps))
        (add-hook hook
                  (lambda ()
                    (apply #'general-define-key
                           :states '(normal motion)
                           :keymaps 'local
                           :prefix (mod-keys--mode-local-prefix)
                           bindings))))
    (apply #'general-define-key
           :keymaps keymaps
           :prefix (mod-keys--mode-local-prefix)
           bindings)))

(use-package which-key
  :ensure (:wait t)
  :demand t
  :config
  (which-key-mode 1))

(use-package general
  :ensure (:wait t)
  :demand t
  :config
  (define-prefix-command 'mod-keys-local-leader-map)

  (if (mod-core-vim-profile-p)
      (progn
        (general-create-definer mod-keys-leader-def
          :states '(normal visual motion emacs)
          :keymaps 'override
          :prefix "SPC")
        (general-create-definer mod-keys-local-leader-def
          :states '(normal visual motion emacs)
          :keymaps 'mod-keys-local-leader-map))
    (general-create-definer mod-keys-leader-def
      :keymaps 'global-map
      :prefix "C-;")
    (general-create-definer mod-keys-local-leader-def
      :keymaps 'mod-keys-local-leader-map))

  (mod-keys-leader-def
    "" '(:ignore t :which-key "leader")
    "SPC" '(consult-buffer :which-key "buffer")
    "." '(mod-keys-find-project-file :which-key "project file")
    "/" '(mod-search-project :which-key "project search")
    ":" '(execute-extended-command :which-key "M-x")
    "," '(find-file :which-key "find file")
    "f" '(:ignore t :which-key "files")
    "f c" '(:ignore t :which-key "config")
    "f c s" '(:ignore t :which-key "snippets")
    "f y" '(:ignore t :which-key "yank path")
    "f c i" '(mod-keys-open-init-file :which-key "init.el")
    "f c e" '(mod-keys-open-early-init-file :which-key "early-init.el")
    "f c m" '(mod-keys-open-modules-directory :which-key "modules/")
    "f c a" '(mod-keys-open-agents-file :which-key "AGENTS.md")
    "f c d" '(mod-keys-open-docs-directory :which-key "docs/")
    "f c r" '(mod-keys-reload-config :which-key "reload")
    "f c u" '(mod-keys-open-user-config-file :which-key "user config")
    "f c U" '(mod-keys-open-user-directory :which-key "user dir")
    "f c S" '(mod-keys-open-user-snippets-directory :which-key "user snippets")
    "f c s e" '(yas-visit-snippet-file :which-key "edit snippet")
    "f c s n" '(yas-new-snippet :which-key "new snippet")
    "f c s r" '(yas-reload-all :which-key "reload snippets")
    "f f" '(orbit-context-open-path :which-key "open path")
    "f o" '(mod-core-open-at-point :which-key "open at point")
    "f r" '(mod-core-recentf-open :which-key "recent")
    "f s" '(save-buffer :which-key "save")
    "f y a" '(mod-core-copy-absolute-file-path :which-key "absolute path")
    "f y r" '(mod-core-copy-project-relative-file-path :which-key "relative path")
    "f y d" '(mod-core-copy-directory-path :which-key "directory path")
    "b" '(:ignore t :which-key "buffers")
    "b b" '(consult-buffer :which-key "switch buffer")
    "b d" '(kill-current-buffer :which-key "kill buffer")
    "b n" '(next-buffer :which-key "next buffer")
    "b p" '(previous-buffer :which-key "previous buffer")
    "b r" '(revert-buffer :which-key "revert")
    "c" '(:ignore t :which-key "code")
    "c d" '(mod-core-duplicate-line-or-region :which-key "duplicate")
    "h" '(:ignore t :which-key "help")
    "h b" '(xref-go-back :which-key "back")
    "h B" '(xref-go-forward :which-key "forward")
    "h h" '(mod-home-open :which-key "home")
    "h k" '(describe-key :which-key "describe key")
    "h f" '(describe-function :which-key "describe function")
    "h d" '(mod-keys-open-docs-manual :which-key "docs manual")
    "h D" '(mod-keys-open-docs-directory :which-key "docs dir")
    "h m" '(describe-mode :which-key "describe mode")
    "h v" '(describe-variable :which-key "describe variable")
    "p" '(:ignore t :which-key "projects")
    "p a" '(mod-project-add :which-key "add project")
    "p d" '(mod-project-forget :which-key "forget")
    "p p" '(mod-project-switch :which-key "switch project")
    "p f" '(project-find-file :which-key "find file")
    "p R" '(mod-project-replace :which-key "replace")
    "p s" '(mod-project-search :which-key "search")
    "s" '(:ignore t :which-key "search")
    "s s" '(mod-search-project :which-key "project")
    "s b" '(mod-search-buffer :which-key "buffer")
    "s f" '(mod-search-project-files :which-key "files")
    "s d" '(mod-search-directory :which-key "directory")
    "s r" '(mod-search-project-replace-query :which-key "replace query")
    "s R" '(mod-search-project-replace-all :which-key "replace all")
    "s S" '(mod-search-project-at-point :which-key "project (at point)")
    "s B" '(consult-line-multi :which-key "all buffers")
    "s i" '(consult-imenu :which-key "imenu")
    "s I" '(consult-imenu-multi :which-key "imenu (all buffers)")
    "s o" '(consult-outline :which-key "outline")
    "s j" '(mod-keys-show-jumps :which-key "jumps")
    "s m" '(consult-mark :which-key "marks")
    "v" '(er/expand-region :which-key "expand region")
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
    "g f" '(:ignore t :which-key "file")
    "g f f" '(mod-git-find-file-from-revision :which-key "from revision")
    "g g" '(mod-git-status :which-key "status")
    "g l" '(mod-git-log :which-key "log")
    "g b" '(mod-git-blame :which-key "blame")
    "g /" '(magit-dispatch :which-key "dispatch")
    "g ." '(magit-file-dispatch :which-key "file dispatch")
    "g D" '(magit-diff :which-key "diff")
    "g L" '(mod-git-log-file :which-key "file log")
    "g S" '(mod-git-stage-file :which-key "stage file")
    "g U" '(mod-git-unstage-file :which-key "unstage file")
    "g ]" '(diff-hl-next-hunk :which-key "next hunk")
    "g [" '(diff-hl-previous-hunk :which-key "prev hunk")
    "g r" '(diff-hl-revert-hunk :which-key "revert hunk")
    "g t" '(git-timemachine :which-key "timemachine")
    "g F" '(forge-list-pullreqs :which-key "list MRs")
    "i" '(:ignore t :which-key "insert")
    "i s" '(yas-insert-snippet :which-key "snippet")
    "m" '(mod-keys-local-leader-map :which-key "local")
    "M" '(:ignore t :which-key "MIB")
    "M f" '(mod-mib-open-or-create-table :which-key "open/create table")
    "M i" '(mod-mib-insert-telecommand :which-key "insert telecommand")
    "M k" '(mod-mib-lookup-tm-packet :which-key "TM packet")
    "M m" '(mod-mib-switch-root :which-key "select root")
    "M o" '(mod-mib-open-detail-source :which-key "open source")
    "M p" '(mod-mib-lookup-tm-parameter :which-key "TM parameter")
    "M r" '(mod-mib-refresh-index :which-key "refresh")
    "M s" '(mod-mib-index-status :which-key "status")
    "M t" '(mod-mib-lookup-telecommand :which-key "telecommand")
    "o" '(:ignore t :which-key "utility")
    "o o" '(mod-utility-toggle :which-key "toggle")
    "o O" '(mod-core-open-at-point :which-key "open at point")
    "o p" '(mod-dired-project-sidebar-toggle :which-key "project files")
    "o s" '(mod-shell-open :which-key "shell")
    "o S" '(mod-shell-new :which-key "new shell")
    "o m" '(mod-utility-messages :which-key "messages")
    "o h" '(mod-utility-help :which-key "help")
    "o c" '(mod-utility-compilation :which-key "compilation")
    "n" '(:ignore t :which-key "notes")
    "n n" '(mod-org-open-notes :which-key "notes")
    "n a" '(mod-org-open-agenda :which-key "agenda")
    "n c" '(:ignore t :which-key "clock")
    "n c g" '(org-clock-goto :which-key "goto active clock")
    "n c o" '(org-clock-out :which-key "clock out")
    "n c c" '(org-clock-cancel :which-key "cancel clock")
    "n C" '(mod-org-capture :which-key "capture")
    "n t" '(mod-org-capture-inbox-task :which-key "inbox task")
    "n j" '(:ignore t :which-key "jira")
    "n j j" '(mod-org-capture-journal :which-key "journal")
    "n j J" '(mod-jira-open-file :which-key "open jira.org")
    "n j c" '(mod-jira-add-comment :which-key "comment")
    "n j i" '(mod-jira-import-issue :which-key "import issue")
    "n j s" '(mod-jira-sync :which-key "sync")
    "n j r" '(mod-jira-refresh-issue :which-key "refresh issue")
    "n j t" '(mod-jira-transition-issue :which-key "transition")
    "n j o" '(mod-jira-open-issue :which-key "open issue")
    "n j w" '(mod-jira-log-work :which-key "worklog")
    "n j W" '(mod-jira-log-work-manual :which-key "manual worklog")
    "n N" '(mod-org-capture-note :which-key "note")
    "n r" '(:ignore t :which-key "roam")
    "n r f" '(org-roam-node-find :which-key "find node")
    "n r i" '(org-roam-node-insert :which-key "insert link")
    "n r b" '(org-roam-buffer-toggle :which-key "backlinks")
    "n r d" '(org-roam-dailies-goto-today :which-key "today")
    "n r D" '(org-roam-dailies-find-date :which-key "pick date")
    "n r c" '(org-roam-capture :which-key "capture")
    "n r s" '(org-roam-db-sync :which-key "db sync")
    "x" '(:ignore t :which-key "contexts")
    "x ." '(orbit-context-dispatch :which-key "panel")
    "x x" '(orbit-context-switch :which-key "switch")
    "x n" '(orbit-context-new :which-key "new")
    "x d" '(orbit-context-delete :which-key "delete")
    "x r" '(orbit-context-rename :which-key "rename")
    "x [" '(orbit-context-previous :which-key "previous")
    "x ]" '(orbit-context-next :which-key "next")
    "x e" '(orbit-context-editor :which-key "edit")
    "x g" '(orbit-context-git :which-key "git")
    "x f" '(orbit-context-files :which-key "files")
    "x b" '(orbit-context-borrow-buffer :which-key "borrow buffer")
    "x B" '(orbit-context-borrow-file :which-key "borrow file")
    "x u" '(orbit-context-unborrow-buffer :which-key "unborrow buffer")
    "x o" '(orbit-context-notes :which-key "notes")
    "x a" '(orbit-context-agenda :which-key "agenda")
    "x s" '(orbit-context-scratch :which-key "scratch")
    "x p" '(orbit-context-project-suite :which-key "project suite")
    "x R" '(orbit-context-related :which-key "related")
    "t" '(:ignore t :which-key "toggles")
    "t f" '(mod-ui-toggle-fullscreen :which-key "fullscreen")
    "t b" '(mod-ui-toggle-big-font :which-key "big font")
    "t c" '(mod-ui-toggle-fill-column-indicator :which-key "fill column")
    "t l" '(mod-ui-toggle-line-numbers :which-key "line numbers")
    "t L" '(mod-ui-toggle-line-number-style :which-key "line number style")
    "t h" '(mod-ui-toggle-hl-line :which-key "highlight line")
    "t s" '(mod-ui-toggle-whitespace :which-key "whitespace")
    "t m" '(mod-ui-toggle-modeline :which-key "modeline")
    "t w" '(mod-ui-toggle-wrap :which-key "wrap")
    "t F" '(mod-theme-select-font :which-key "choose font")
    "t T" '(mod-theme-select :which-key "choose theme")
    "q" '(:ignore t :which-key "quit")
    "q s" '(mod-session-save :which-key "save session")
    "q l" '(mod-session-load :which-key "load session")
    "q q" '(save-buffers-kill-terminal :which-key "quit"))

  (mod-keys-local-leader-def
    "" '(:ignore t :which-key "local"))

  (with-eval-after-load 'org
    (when (fboundp 'evil-ret)
      (setq mod-org-return-fallback-command #'evil-ret))
    (when (mod-core-vim-profile-p)
      (general-define-key
       :states '(normal)
       :keymaps 'org-mode-map
       (kbd "RET") #'mod-org-open-at-point-dwim))
    (define-key org-mode-map (kbd "TAB") #'mod-org-tab-dwim)
    (define-key org-mode-map (kbd "<tab>") #'mod-org-tab-dwim)
    (define-key org-mode-map (kbd "<backtab>") #'mod-org-backtab-dwim)
    (when (fboundp 'evil-define-key)
      (evil-define-key '(normal insert motion emacs) org-mode-map
        (kbd "TAB") #'mod-org-tab-dwim
        (kbd "<tab>") #'mod-org-tab-dwim
        (kbd "<backtab>") #'mod-org-backtab-dwim))
    (mod-keys--define-mode-local
     'org-mode-map
     "J" '(org-metadown :which-key "move down")
     "K" '(org-metaup :which-key "move up")
     "H" '(org-metaleft :which-key "promote")
     "L" '(org-metaright :which-key "demote")
     "i" '(:ignore t :which-key "insert")
     "i h" '(org-insert-heading :which-key "heading")
     "i t" '(org-insert-todo-heading :which-key "todo heading")
     "i s" '(org-insert-subheading :which-key "subheading")
     "a" '(:ignore t :which-key "attachments")
     "a a" '(mod-org-attach-file :which-key "attach file")
     "a d" '(mod-org-attachment-directory :which-key "directory")
     "a i" '(mod-org-insert-attached-image :which-key "insert image")
     "a t" '(mod-org-toggle-inline-images :which-key "toggle images")
     "c" '(:ignore t :which-key "context")
     "c x" '(org-toggle-checkbox :which-key "checkbox")
     "c i" '(org-clock-in :which-key "clock in")
     "c o" '(org-clock-out :which-key "clock out")
     "c c" '(org-clock-cancel :which-key "clock cancel")
     "c g" '(org-clock-goto :which-key "clock goto")
     "c l" '(mod-org-capture-linked-task :which-key "linked task")
     "c j" '(mod-org-capture-jira-follow-up :which-key "jira follow-up")
     "c d" '(mod-org-capture-investigation :which-key "investigation")
     "c m" '(mod-org-capture-meeting-action :which-key "meeting action")
     "c e" '(mod-org-capture-evidence :which-key "evidence")
     "d" '(:ignore t :which-key "diagrams")
     "d f" '(mod-mermaid-insert-flowchart :which-key "flowchart")
     "d s" '(mod-mermaid-insert-sequence :which-key "sequence")
     "d t" '(mod-mermaid-insert-state :which-key "state")
     "d T" '(mod-mermaid-insert-timeline :which-key "timeline")
     "d p" '(mod-mermaid-preview :which-key "preview")
     "d P" '(mod-mermaid-auto-preview-mode :which-key "auto preview")
     "d e" '(org-babel-execute-src-block :which-key "execute block")
     "l" '(mod-org-insert-node-link :which-key "node link")
     "L" '(mod-org-insert-heading-link :which-key "heading link")
     "RET" '(mod-org-open-link-at-point :which-key "open link")
     "o" '(consult-outline :which-key "outline")
     "n" '(org-next-visible-heading :which-key "next heading")
     "p" '(org-previous-visible-heading :which-key "previous heading")
     "u" '(outline-up-heading :which-key "up heading")
     "z" '(org-narrow-to-subtree :which-key "narrow subtree")
     "Z" '(widen :which-key "widen")
     "TAB" '(org-cycle :which-key "cycle")
     "T" '(:ignore t :which-key "table")
     "T a" '(mod-org-table-align :which-key "align")
     "T c" '(mod-org-table-create-or-convert-from-region :which-key "create/convert")
     "T r" '(mod-org-table-recalculate :which-key "recalculate")
     "T n" '(mod-org-table-next-row :which-key "next row")
     "T i" '(:ignore t :which-key "insert")
     "T i r" '(mod-org-table-insert-row :which-key "row")
     "T i c" '(mod-org-table-insert-column :which-key "column")
     "T d" '(:ignore t :which-key "delete")
     "T d r" '(mod-org-table-kill-row :which-key "row")
     "T d c" '(mod-org-table-delete-column :which-key "column")
     "t" '(org-todo :which-key "todo")
     "s" '(org-schedule :which-key "schedule")
     "D" '(org-deadline :which-key "deadline")
     "r" '(org-refile :which-key "refile")
     "A" '(org-archive-subtree :which-key "archive")
     "P" '(org-priority :which-key "priority")
     "v" '(:ignore t :which-key "view")
     "v e" '(mod-org-toggle-emphasis-markers :which-key "emphasis")
     "v i" '(mod-org-toggle-inline-images :which-key "inline images")
     "v p" '(mod-org-toggle-pretty-view :which-key "pretty")
     "v d" '(mod-org-toggle-property-drawers :which-key "drawers")
     "m" '(:ignore t :which-key "mermaid")
     "m p" '(mod-mermaid-preview :which-key "preview")
     "m P" '(mod-mermaid-auto-preview-mode :which-key "auto preview")
     "m e" '(org-babel-execute-src-block :which-key "execute block")))

  (with-eval-after-load 'tcl
    (mod-keys--define-mode-local
     'tcl-mode-map
     "d" '(:ignore t :which-key "docs")
     "d d" '(mod-tcl-docs-manual :which-key "project manual")
     "d s" '(mod-tcl-docs-search :which-key "search docs")
     "d p" '(mod-tcl-docs-at-point :which-key "docs at point")
     "d r" '(mod-tcl-docs-regenerate :which-key "regen docs")
     "l" '(mod-tcl-lint-file :which-key "lint")
     "f" '(mod-tcl-format-file :which-key "format")
     "F" '(mod-tcl-fold-definitions :which-key "fold definitions")
     "D" '(mod-tcl-fold-doxygen-comments :which-key "fold doxygen comments")
     "TAB" '(mod-tcl-toggle-fold :which-key "toggle fold")
     "a" '(mod-tcl-ait-jump :which-key "AIT block")
     "n" '(mod-tcl-next-definition :which-key "next definition")
     "p" '(mod-tcl-previous-definition :which-key "previous definition")
     "g" '(mod-tcl-find-tag :which-key "goto tag")
     "s" '(mod-tcl-search-symbols :which-key "search symbols")
     "v" '(mod-tcl-validate-tooling :which-key "validate tools")
     "r" '(:ignore t :which-key "refactor")
     "r r" '(mod-tcl-rename-local-symbol :which-key "rename local")
     "r t" '(mod-tcl-rebuild-tags :which-key "rebuild TAGS")
     "e" '(mod-tcl-show-output :which-key "tool output")))

  (with-eval-after-load 'python
    (mod-keys--define-mode-local
     '(python-mode-map python-ts-mode-map)
     "e" '(:ignore t :which-key "eglot")
     "e s" '(mod-python-eglot :which-key "start")
     "e R" '(mod-python-eglot-reconnect :which-key "reconnect")
     "e r" '(eglot-rename :which-key "rename")
     "e h" '(mod-python-show-docs :which-key "docs")
     "f" '(:ignore t :which-key "format")
     "f b" '(mod-python-format-buffer :which-key "buffer")
     "g" '(:ignore t :which-key "goto")
     "g d" '(xref-find-definitions :which-key "definition")
     "g r" '(xref-find-references :which-key "references")
     "r" '(:ignore t :which-key "run")
     "r f" '(mod-python-run-file :which-key "file")
     "r m" '(mod-python-run-module :which-key "module")
     "d" '(:ignore t :which-key "debug")
     "d d" '(mod-python-debug-file :which-key "debug file")
     "d b" '(dape-breakpoint-toggle :which-key "toggle breakpoint")
     "d x" '(dape-breakpoint-remove-at-point :which-key "remove breakpoint")
     "d X" '(dape-breakpoint-remove-all :which-key "remove all breakpoints")
     "d e" '(dape-breakpoint-expression :which-key "expression breakpoint")
     "d l" '(dape-breakpoint-log :which-key "log breakpoint")
     "d f" '(dape-breakpoint-function :which-key "function breakpoint")
     "d w" '(dape-watch-dwim :which-key "watch dwim")
     "d c" '(dape-continue :which-key "continue")
     "d p" '(dape-pause :which-key "pause")
     "d n" '(dape-next :which-key "next")
     "d i" '(dape-step-in :which-key "step in")
     "d o" '(dape-step-out :which-key "step out")
     "d r" '(mod-python-debug-restart :which-key "restart")
     "d q" '(dape-kill :which-key "quit")
     "d R" '(dape-repl :which-key "repl")
     "d I" '(dape-info :which-key "info")))

  (with-eval-after-load 'mermaid-mode
    (mod-keys--define-mode-local
     'mermaid-mode-map
     "p" '(mod-mermaid-preview :which-key "preview")
     "P" '(mod-mermaid-auto-preview-mode :which-key "auto preview")
     "e" '(mermaid-compile-buffer :which-key "compile")
     "o" '(mermaid-open-browser :which-key "open in browser")))

  (with-eval-after-load 'mod-mib
    (mod-keys--define-mode-local
     'mod-mib-mode-map
     "m" '(mod-mib-switch-root :which-key "switch root")
     "t" '(mod-mib-open-table :which-key "open table")
     "T" '(mod-mib-open-table-other-root :which-key "same table other root")
     "c" '(mod-mib-jump-column :which-key "column")
     "e" '(mod-mib-edit-field :which-key "edit field")
     "r" '(mod-mib-toggle-column-header :which-key "column header")
     "a" '(mod-mib-realign :which-key "align")
     "n" '(mod-mib-next-row :which-key "next row")
     "p" '(mod-mib-previous-row :which-key "previous row")
     "]" '(mod-mib-next-field :which-key "next field")
     "[" '(mod-mib-previous-field :which-key "previous field")
     "C" '(mod-mib-compare-table :which-key "compare table")))

  (with-eval-after-load 'markdown-mode
    (mod-keys--define-mode-local
     '(markdown-mode-map gfm-mode-map)
     "p" '(markdown-preview :which-key "preview")
     "e" '(markdown-export :which-key "export to html")
     "t" '(markdown-toggle-gfm-checkbox :which-key "toggle checkbox")
     "i" '(markdown-insert-image :which-key "insert image")
     "l" '(markdown-insert-link :which-key "insert link")))

  (with-eval-after-load 'dape
    (if (mod-core-vim-profile-p)
        (general-define-key
         :states '(normal motion emacs)
         :keymaps '(dape-repl-mode-map
                    dape-info-parent-mode-map
                    dape-shell-mode-map)
         "c" #'dape-continue
         "n" #'dape-next
         "i" #'dape-step-in
         "o" #'dape-step-out
         "p" #'dape-pause
         "r" #'dape-restart
         "q" #'dape-kill
         "b" #'dape-breakpoint-toggle
         "x" #'dape-breakpoint-remove-at-point
         "w" #'dape-watch-dwim
         "R" #'dape-repl
         "I" #'dape-info)
      (general-define-key
       :keymaps '(dape-repl-mode-map
                  dape-info-parent-mode-map
                  dape-shell-mode-map)
       "c" #'dape-continue
       "n" #'dape-next
       "i" #'dape-step-in
       "o" #'dape-step-out
       "p" #'dape-pause
       "r" #'dape-restart
       "q" #'dape-kill
       "b" #'dape-breakpoint-toggle
       "x" #'dape-breakpoint-remove-at-point
       "w" #'dape-watch-dwim
       "R" #'dape-repl
       "I" #'dape-info)))

  (with-eval-after-load 'org-agenda
    (define-key org-agenda-mode-map (kbd "j") #'org-agenda-next-line)
    (define-key org-agenda-mode-map (kbd "k") #'org-agenda-previous-line)
    (define-key org-agenda-mode-map (kbd "RET") #'mod-org-agenda-visit)
    (when (fboundp 'evil-define-key)
      (evil-define-key '(normal motion emacs) org-agenda-mode-map
        (kbd "j") #'org-agenda-next-line
        (kbd "k") #'org-agenda-previous-line
        (kbd "RET") #'mod-org-agenda-visit))
    (mod-keys--define-motion-mode-local
     'org-agenda-mode-map
     "c" '(:ignore t :which-key "clock")
     "c i" '(org-agenda-clock-in :which-key "clock in")
     "c o" '(org-agenda-clock-out :which-key "clock out")
     "c c" '(org-agenda-clock-cancel :which-key "clock cancel")
     "c g" '(org-agenda-clock-goto :which-key "clock goto")
     "t" '(org-agenda-todo :which-key "todo")
     "s" '(org-agenda-schedule :which-key "schedule")
     "d" '(org-agenda-deadline :which-key "deadline")
     "r" '(org-agenda-refile :which-key "refile")
     "a" '(org-agenda-archive :which-key "archive")
     "v" '(mod-org-agenda-visit :which-key "visit"))))

(easy-menu-define mod-keys-orbit-menu global-map
  "Menu bar entries for the Orbit command language."
  '("Orbit"
    ["Switch Buffer" consult-buffer t]
    ["Find Project File" mod-keys-find-project-file t]
    ["Find File Anywhere" find-file t]
    ["M-x" execute-extended-command t]
    "---"
    ("Files"
     ["Open Path" orbit-context-open-path t]
     ["Open At Point" mod-core-open-at-point t]
     ["Recent Files" mod-core-recentf-open t]
     ["Save Buffer" save-buffer t])
    ("Buffers"
     ["Switch Buffer" consult-buffer t]
     ["Kill Buffer" kill-current-buffer t]
     ["Next Buffer" next-buffer t]
     ["Previous Buffer" previous-buffer t]
     ["Revert Buffer" revert-buffer t])
    ("Projects"
     ["Switch Project" mod-project-switch t]
     ["Find Project File" project-find-file t]
     ["Search Project" mod-project-search t]
     ["Replace In Project" mod-project-replace t])
    ("Search"
     ["Project Search" mod-search-project t]
     ["Buffer Search" mod-search-buffer t]
     ["Find Project Files" mod-search-project-files t]
     ["Directory Search" mod-search-directory t])
    ("Git"
     ["Status" mod-git-status t]
     ["Log" mod-git-log t]
     ["Blame" mod-git-blame t]
     ["Magit Dispatch" magit-dispatch t])
    ("Notes"
     ["Open Notes" mod-org-open-notes t]
     ["Open Agenda" mod-org-open-agenda t]
     ["Capture" mod-org-capture t]
     ["Inbox Task" mod-org-capture-inbox-task t])
    ("Contexts"
     ["Panel" orbit-context-dispatch t]
     ["Switch" orbit-context-switch t]
     ["New" orbit-context-new t]
     ["Delete" orbit-context-delete t]
     ["Rename" orbit-context-rename t]
     ["Project Suite" orbit-context-project-suite t])
    ("Toggles"
     ["Fullscreen" mod-ui-toggle-fullscreen t]
     ["Big Font" mod-ui-toggle-big-font t]
     ["Choose Font" mod-theme-select-font t]
     ["Line Numbers" mod-ui-toggle-line-numbers t]
     ["Wrap" mod-ui-toggle-wrap t]
     ["Choose Theme" mod-theme-select t])
    ("Help"
     ["Orbit Home" mod-home-open t]
     ["Manual" mod-keys-open-docs-manual t]
     ["Describe Key" describe-key t]
     ["Describe Mode" describe-mode t])))

(when (mod-core-menu-bar-enabled-p)
  (easy-menu-add mod-keys-orbit-menu global-map))

(global-set-key (kbd "M-j") #'mod-core-move-line-or-region-down)
(global-set-key (kbd "M-k") #'mod-core-move-line-or-region-up)
(when orbit-user-font-resize-keys
  (global-set-key (kbd "C--") #'mod-theme-decrease-font-height)
  (global-set-key (kbd "C-+") #'mod-theme-increase-font-height)
  (global-set-key (kbd "C-=") #'mod-theme-increase-font-height))

(with-eval-after-load 'evil
  (general-define-key
   :states '(normal visual insert motion emacs)
   :keymaps 'override
   "M-j" #'mod-core-move-line-or-region-down
   "M-k" #'mod-core-move-line-or-region-up))

(provide 'mod-keys)

;;; mod-keys.el ends here
