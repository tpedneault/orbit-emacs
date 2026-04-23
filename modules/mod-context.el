;;; mod-context.el --- Context foundation -*- lexical-binding: t; -*-

(require 'project)

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

(defun mod-context--switch-or-create (name)
  "Switch to context NAME, creating it if needed."
  (persp-switch name))

(defun mod-context--exists-p (name)
  "Return non-nil when a Perspective context NAME already exists."
  (gethash name (perspectives-hash)))

(defun mod-context-current-name ()
  "Return the current context name, or nil."
  (when (bound-and-true-p persp-mode)
    (ignore-errors (persp-current-name))))

(defun mod-context--edit-context-name (root)
  "Return the edit context name for ROOT."
  (format "edit/%s" (mod-context--directory-name root)))

(defun mod-context--files-context-name (root)
  "Return the files context name for ROOT."
  (format "files/%s" (mod-context--directory-name root)))

(defun mod-context--activate-template (name opener)
  "Switch to context NAME and run OPENER there."
  (mod-context--switch-or-create name)
  (funcall opener))

(defun mod-context--project-root ()
  "Return the current project root, or nil if not in a project."
  (when-let ((project (project-current nil)))
    (project-root project)))

(defun mod-context--read-known-project-root ()
  "Prompt for one of the known project roots."
  (let ((projects (project-known-project-roots)))
    (unless projects
      (user-error "No known projects available"))
    (completing-read "Project: " projects nil t)))

(defun mod-context--directory-name (dir)
  "Return the final directory name component of DIR."
  (file-name-nondirectory (directory-file-name dir)))

(defun mod-context--git-root ()
  "Return the current Git root, or nil if none can be determined."
  (or (mod-context--project-root)
      (vc-root-dir)))

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
  "Switch to a Git context for the current project or repository."
  (interactive)
  (let* ((root (mod-context--git-root))
         (name (and root (format "git/%s" (mod-context--directory-name root)))))
    (unless root
      (user-error "Not in a project or Git repository"))
    (if (mod-context--exists-p name)
        (persp-switch name)
      (mod-context--activate-template
       name
       (lambda ()
         (let ((default-directory root))
           (mod-git-status)
           (delete-other-windows)))))))

(defun mod-context-editor ()
  "Switch to an editing context for a project."
  (interactive)
  (let* ((root (or (mod-context--project-root)
                   (mod-context--read-known-project-root)))
         (name (mod-context--edit-context-name root)))
    (let ((default-directory root))
      (mod-context--switch-or-create name))))

(defun mod-context-files ()
  "Switch to a file-management context for the current project or directory."
  (interactive)
  (let* ((root (or (mod-context--project-root) default-directory))
         (name (mod-context--files-context-name root)))
    (mod-context--activate-template
     name
     (lambda ()
       (let ((default-directory root))
         (mod-dired-here))))))

(defun mod-context--files-root-for-directory (dir)
  "Return the matching edit/files root for DIR."
  (let ((default-directory dir))
    (or (mod-context--project-root) dir)))

(defun mod-context-dired-find-file-advice (orig-fun &rest args)
  "Open files from a files context in the matching edit context.
ORIG-FUN is the original `dired-find-file' function and ARGS are its
arguments."
  (if (and (derived-mode-p 'dired-mode)
           (string-prefix-p "files/" (or (mod-context-current-name) "")))
      (let* ((path (dired-get-file-for-visit))
             (root (mod-context--files-root-for-directory default-directory)))
        (if (file-directory-p path)
            (apply orig-fun args)
          (let ((default-directory root))
            (persp-switch (mod-context--edit-context-name root))
            (find-file path))))
    (apply orig-fun args)))

(advice-add 'dired-find-file :around #'mod-context-dired-find-file-advice)

(defun mod-context-notes ()
  "Switch to the notes context."
  (interactive)
  (mod-context--activate-template "notes" #'mod-org-open-notes))

(defun mod-context-notes-visit-marker (marker)
  "Switch to the notes context and visit MARKER there."
  (mod-context--activate-template
   "notes"
   (lambda ()
     (switch-to-buffer (marker-buffer marker))
     (goto-char marker)
     (when (derived-mode-p 'org-mode)
       (org-fold-show-context 'agenda)
       (org-show-entry)))))

(defun mod-context-agenda ()
  "Switch to the agenda context."
  (interactive)
  (mod-context--activate-template
   "agenda"
   (lambda ()
     (mod-org-open-agenda)
     (delete-other-windows))))

(defun mod-context-scratch ()
  "Switch to the scratch context."
  (interactive)
  (mod-context--activate-template "scratch" #'persp-switch-to-scratch-buffer))

(provide 'mod-context)

;;; mod-context.el ends here
