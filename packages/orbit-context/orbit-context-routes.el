;;; orbit-context-routes.el --- Routing and openers -*- lexical-binding: t; -*-

(declare-function mod-dired-here "mod-dired")
(declare-function mod-git-status "mod-git")
(declare-function mod-org-open-agenda "mod-org")
(declare-function mod-org-open-notes "mod-org")

(defun orbit-context--mark-buffer-for-current-context (buffer role)
  "Attach BUFFER to the current context with ROLE."
  (when-let* ((name (orbit-context-current-name)))
    (orbit-context--mark-buffer
     buffer
     role
     (orbit-context-current-root name)
     name)))

(defun orbit-context--mark-current-buffer-for-current-context (role)
  "Attach the current buffer to the active context with ROLE."
  (orbit-context--mark-buffer-for-current-context (current-buffer) role))

(defun orbit-context--mark-current-buffer-utility ()
  "Mark the current buffer as utility-owned rather than context-owned."
  (orbit-context--mark-buffer (current-buffer) 'utility))

(defun orbit-context--compilation-buffer-setup ()
  "Attach compilation buffers to the context that started them."
  (orbit-context--mark-current-buffer-for-current-context 'local))

(defun orbit-context--xref-buffer-setup ()
  "Attach xref result buffers to the context that created them."
  (orbit-context--mark-current-buffer-for-current-context 'local))

(defun orbit-context--occur-buffer-setup ()
  "Attach occur buffers to the context that created them."
  (orbit-context--mark-current-buffer-for-current-context 'local))

(defun orbit-context--help-buffer-setup ()
  "Mark help-like buffers as utility-space buffers."
  (orbit-context--mark-current-buffer-utility))

(defun orbit-context--magit-buffer-setup ()
  "Attach Magit support buffers to the current Git context."
  (let ((current-name (orbit-context-current-name)))
    (cond
     ((and current-name
           (eq (orbit-context-current-kind current-name) 'git-project))
      (orbit-context--mark-buffer
       (current-buffer)
       'git
       (orbit-context-current-root current-name)
       current-name))
     ((and (buffer-file-name)
           (orbit-context--project-root-for-file (buffer-file-name)))
      (let* ((root (orbit-context--project-root-for-file (buffer-file-name)))
             (group (orbit-context--directory-name root)))
        (orbit-context--mark-buffer
         (current-buffer)
         'git
         root
         (format "git/%s" group))))
     ((and default-directory
           (orbit-context--project-root))
      (let* ((root (orbit-context--project-root))
             (group (orbit-context--directory-name root)))
        (orbit-context--mark-buffer
         (current-buffer)
         'git
         root
         (format "git/%s" group)))))))

(defun orbit-context--activate-template (name opener)
  "Switch to context NAME and run OPENER there."
  (orbit-context--switch-or-create name)
  (funcall opener))

(defun orbit-context--open-project-file-in-edit-context (root)
  "Prompt for and open a project file for ROOT in the current edit context."
  (let ((default-directory root))
    (call-interactively #'project-find-file)))

(defun orbit-context--files-root-for-directory (dir)
  "Return the matching edit/files root for DIR."
  (let ((default-directory dir))
    (or (orbit-context--project-root) dir)))

(defun orbit-context-open-path (path)
  "Open PATH in the appropriate edit or files context."
  (interactive "FOpen path: ")
  (let ((expanded (expand-file-name path)))
    (if (file-directory-p expanded)
        (let ((default-directory expanded))
          (orbit-context--ensure-files-context-metadata
           (orbit-context--files-root-for-directory expanded))
          (orbit-context--activate-template
           (orbit-context--files-context-name-for-directory expanded)
           (lambda ()
             (let ((default-directory expanded))
               (mod-dired-here)
               (orbit-context--mark-buffer
                (current-buffer) 'files
                (orbit-context--files-root-for-directory expanded))))))
      (let* ((root (orbit-context--project-root-for-file expanded))
             (context-name (orbit-context--edit-context-name-for-file expanded))
             (default-directory (or root (file-name-directory expanded))))
        (when root
          (orbit-context--ensure-project-context-metadata root))
        (when context-name
          (orbit-context--switch-owned context-name))
        (find-file expanded)))))

(defun orbit-context--move-current-buffer-to-roam-context ()
  "Move the current Org-roam buffer into `edit/org-roam'."
  (when (and buffer-file-name
             (orbit-context--roam-file-p buffer-file-name))
    (let ((buffer (current-buffer))
          (point (point))
          (window-start (window-start)))
      (orbit-context--switch-or-create orbit-context-roam-edit-context-name)
      (switch-to-buffer buffer)
      (goto-char point)
      (set-window-start (selected-window) window-start))))

(defun orbit-context--org-roam-open-advice (&rest _)
  "Route the current Org-roam file into `edit/org-roam'."
  (orbit-context--move-current-buffer-to-roam-context))

(defun orbit-context-open-project-editor (&optional project)
  "Switch to the edit context for PROJECT."
  (let* ((project (or project (orbit-context--select-project)))
         (root (plist-get project :root))
         (name (format "edit/%s" (plist-get project :name)))
         (should-prompt (or (not (orbit-context--exists-p name))
                            (orbit-context--edit-context-empty-p name root))))
    (let ((default-directory root))
      (orbit-context--ensure-project-context-metadata root)
      (orbit-context--switch-owned
       name
       (when should-prompt
         (lambda ()
           (orbit-context--open-project-file-in-edit-context root)))))))

(defun orbit-context-editor ()
  "Switch to an editing context for a project."
  (interactive)
  (orbit-context-open-project-editor))

(defun orbit-context-git ()
  "Switch to a Git context for the current project or repository."
  (interactive)
  (let* ((project (orbit-context--select-project))
         (root (plist-get project :root))
         (name (format "git/%s" (plist-get project :name))))
    (orbit-context--ensure-project-context-metadata root)
    (orbit-context--switch-owned
     name
     (lambda ()
       (let ((default-directory root))
         (mod-git-status)
         (orbit-context--mark-buffer (current-buffer) 'git root)
         (delete-other-windows))))))

(defun orbit-context-files ()
  "Switch to a file-management context for the current project or directory."
  (interactive)
  (let* ((root (or (orbit-context--project-root) default-directory))
         (name (orbit-context--files-context-name root)))
    (if (orbit-context--project-root)
        (orbit-context--ensure-project-context-metadata root)
      (orbit-context--ensure-files-context-metadata root))
    (orbit-context--switch-owned
     name
     (lambda ()
       (let ((default-directory root))
         (mod-dired-here)
         (orbit-context--mark-buffer (current-buffer) 'files root))))))

(defun orbit-context-dired-find-file-advice (orig-fun &rest args)
  "Open files from a files context in the matching edit context."
  (if (and (derived-mode-p 'dired-mode)
           (string-prefix-p "files/" (or (orbit-context-current-name) "")))
      (let ((path (dired-get-file-for-visit)))
        (if (file-directory-p path)
            (apply orig-fun args)
          (orbit-context-open-path path)))
    (apply orig-fun args)))

(advice-add 'dired-find-file :around #'orbit-context-dired-find-file-advice)

(add-hook 'compilation-mode-hook #'orbit-context--compilation-buffer-setup)
(add-hook 'occur-hook #'orbit-context--occur-buffer-setup)
(add-hook 'help-mode-hook #'orbit-context--help-buffer-setup)
(add-hook 'shell-mode-hook #'orbit-context--help-buffer-setup)
(add-hook 'eshell-mode-hook #'orbit-context--help-buffer-setup)

(with-eval-after-load 'xref
  (add-hook 'xref--xref-buffer-mode-hook #'orbit-context--xref-buffer-setup))

(with-eval-after-load 'apropos
  (add-hook 'apropos-mode-hook #'orbit-context--help-buffer-setup))

(with-eval-after-load 'eat
  (add-hook 'eat-mode-hook #'orbit-context--help-buffer-setup))

(with-eval-after-load 'magit
  (add-hook 'magit-mode-hook #'orbit-context--magit-buffer-setup)
  (add-hook 'git-commit-mode-hook #'orbit-context--magit-buffer-setup)
  (add-hook 'diff-mode-hook #'orbit-context--magit-buffer-setup))

(with-eval-after-load 'org-roam
  (dolist (fn '(org-roam-node-find
                org-roam-node-visit
                org-roam-capture
                org-roam-dailies-goto-today
                org-roam-dailies-find-date))
    (advice-add fn :after #'orbit-context--org-roam-open-advice)))

(defun orbit-context-notes ()
  "Switch to the notes context."
  (interactive)
  (orbit-context--set-context-metadata "notes" (list :kind 'notes))
  (orbit-context--switch-owned
   "notes"
   (lambda ()
     (mod-org-open-notes)
     (orbit-context--mark-buffer (current-buffer) 'notes))))

(defun orbit-context-notes-visit-marker (marker)
  "Switch to the notes context and visit MARKER there."
  (orbit-context--set-context-metadata "notes" (list :kind 'notes))
  (orbit-context--switch-owned
   "notes"
   (lambda ()
     (switch-to-buffer (marker-buffer marker))
     (orbit-context--mark-buffer (current-buffer) 'notes)
     (goto-char marker)
     (when (derived-mode-p 'org-mode)
       (org-fold-show-context 'agenda)
       (org-show-entry)))))

(defun orbit-context-agenda ()
  "Switch to the agenda context."
  (interactive)
  (orbit-context--set-context-metadata "agenda" (list :kind 'agenda))
  (orbit-context--switch-owned
   "agenda"
   (lambda ()
     (mod-org-open-agenda)
     (orbit-context--mark-buffer (current-buffer) 'agenda)
     (delete-other-windows))))

(defun orbit-context-scratch ()
  "Switch to the scratch context."
  (interactive)
  (orbit-context--set-context-metadata "scratch" (list :kind 'scratch))
  (orbit-context--switch-owned
   "scratch"
   (lambda ()
     (persp-switch-to-scratch-buffer)
     (orbit-context--mark-buffer (current-buffer) 'scratch))))

(provide 'orbit-context-routes)

;;; orbit-context-routes.el ends here
