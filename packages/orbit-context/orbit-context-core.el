;;; orbit-context-core.el --- Core context behavior -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'project)
(require 'seq)

(declare-function mod-roam-directory "mod-roam")

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

(defvar orbit-context--metadata (make-hash-table :test 'equal)
  "Metadata for named contexts.")

(defvar-local orbit-context--buffer-role nil
  "Logical orbit context role for the current buffer.")

(defvar-local orbit-context--buffer-root nil
  "Associated root path for the current buffer when orbit tracks one explicitly.")

(defvar-local orbit-context--buffer-context-name nil
  "Exact orbit context name the current buffer is attached to, when explicit.")

(defvar-local orbit-context--borrowed-contexts nil
  "Context names this buffer is explicitly borrowed into.")

(defvar orbit-context--buffer-policies nil
  "Registry of orbit transient buffer policies.")

(defconst orbit-context--history-limit 20
  "Maximum number of recent buffers or files tracked per context.")

(defconst orbit-context--kind-display-names
  '((edit-project . "EDIT")
    (git-project . "GIT")
    (files-root . "FILES")
    (edit-roam . "ROAM")
    (edit-loose . "LOOSE")
    (notes . "NOTES")
    (agenda . "AGENDA")
    (scratch . "SCRATCH"))
  "Display names for orbit context kinds.")

(defconst orbit-context-loose-edit-context-name "edit/loose"
  "Dedicated edit context name for files outside recognized projects.")

(defconst orbit-context-roam-edit-context-name "edit/org-roam"
  "Dedicated edit context name for Org-roam files.")

(defun orbit-context-current-name ()
  "Return the current context name, or nil."
  (when (bound-and-true-p persp-mode)
    (ignore-errors (persp-current-name))))

(defun orbit-context-current-kind (&optional name)
  "Return the current context kind, or that of NAME when provided."
  (plist-get (orbit-context--context-metadata (or name (orbit-context-current-name))) :kind))

(defun orbit-context-current-group (&optional name)
  "Return the current context group, or that of NAME when provided."
  (plist-get (orbit-context--context-metadata (or name (orbit-context-current-name))) :group))

(defun orbit-context-current-root (&optional name)
  "Return the current context root, or that of NAME when provided."
  (plist-get (orbit-context--context-metadata (or name (orbit-context-current-name))) :root))

(defun orbit-context--switch-or-create (name)
  "Switch to context NAME, creating it if needed."
  (persp-switch name))

(defun orbit-context-register-buffer-policy (name policy predicate &optional description)
  "Register a transient buffer policy under NAME.
POLICY must be one of `:local', `:utility', or `:ignore'. PREDICATE is called
with the buffer to classify. DESCRIPTION is a short diagnostic summary."
  (unless (memq policy '(:local :utility :ignore))
    (user-error "Unknown orbit buffer policy: %S" policy))
  (setq orbit-context--buffer-policies
        (assq-delete-all name orbit-context--buffer-policies))
  (push (list name :policy policy :predicate predicate :description description)
        orbit-context--buffer-policies)
  name)

(defun orbit-context-buffer-policy (&optional buffer)
  "Return the matching transient buffer policy plist for BUFFER, or nil."
  (let ((buffer (or buffer (current-buffer))))
    (cl-loop for entry in orbit-context--buffer-policies
             for name = (car entry)
             for policy = (plist-get (cdr entry) :policy)
             for predicate = (plist-get (cdr entry) :predicate)
             for description = (plist-get (cdr entry) :description)
             when (and (buffer-live-p buffer)
                       (functionp predicate)
                       (funcall predicate buffer))
             return (list :name name
                          :policy policy
                          :description description))))

(defun orbit-context--exists-p (name)
  "Return non-nil when context NAME already exists."
  (gethash name (perspectives-hash)))

(defun orbit-context--set-context-metadata (name metadata)
  "Associate METADATA with context NAME and return it."
  (puthash name metadata orbit-context--metadata)
  metadata)

(defun orbit-context--metadata-update (name updater)
  "Update context NAME metadata with UPDATER and return the new plist."
  (let* ((metadata (copy-sequence (orbit-context--context-metadata name)))
         (updated (funcall updater metadata)))
    (orbit-context--set-context-metadata name updated)))

(defun orbit-context--context-metadata (name)
  "Return metadata plist for context NAME."
  (or (gethash name orbit-context--metadata)
      (let ((metadata
             (cond
              ((equal name orbit-context-loose-edit-context-name)
               (list :kind 'edit-loose))
              ((equal name orbit-context-roam-edit-context-name)
               (list :kind 'edit-roam))
              ((equal name "notes")
               (list :kind 'notes))
              ((equal name "agenda")
               (list :kind 'agenda))
              ((equal name "scratch")
               (list :kind 'scratch))
              ((and name (string-prefix-p "edit/" name))
               (list :kind 'edit-project
                     :group (string-remove-prefix "edit/" name)))
              ((and name (string-prefix-p "git/" name))
               (list :kind 'git-project
                     :group (string-remove-prefix "git/" name)))
              ((and name (string-prefix-p "files/" name))
               (list :kind 'files-root
                     :group (string-remove-prefix "files/" name)))
              (t nil))))
        (when metadata
          (puthash name metadata orbit-context--metadata))
        metadata)))

(defun orbit-context--kind-display-name (kind)
  "Return a display label for context KIND."
  (or (alist-get kind orbit-context--kind-display-names)
      "CONTEXT"))

(defun orbit-context-related-names (&optional name)
  "Return names of contexts related to NAME or the current context."
  (let* ((name (or name (orbit-context-current-name)))
         (metadata (orbit-context--context-metadata name))
         (kind (plist-get metadata :kind))
         (group (plist-get metadata :group))
         (root (plist-get metadata :root)))
    (cond
     ((and group (memq kind '(edit-project git-project files-root)))
      (list (format "edit/%s" group)
            (format "git/%s" group)
            (format "files/%s" group)))
     ((memq kind '(notes agenda edit-roam))
      (list "agenda" "notes" orbit-context-roam-edit-context-name))
     (t nil))))

(defun orbit-context--related-hint (&optional name)
  "Return a short related-context hint for NAME or the current context."
  (let* ((name (or name (orbit-context-current-name)))
         (metadata (orbit-context--context-metadata name))
         (related (delete name (copy-sequence (orbit-context-related-names name))))
         (labels
          (delq nil
                (mapcar
                 (lambda (candidate)
                   (pcase (plist-get (orbit-context--context-metadata candidate) :kind)
                     ('edit-project "edit")
                     ('git-project "git")
                     ('files-root "files")
                     ('notes "notes")
                     ('agenda "agenda")
                     ('edit-roam "roam")
                     (_ nil)))
                 related))))
    (when (and labels
               (memq (plist-get metadata :kind)
                     '(edit-project git-project files-root notes agenda edit-roam)))
      (string-join labels "/"))))

(defun orbit-context-modeline-label (&optional name)
  "Return a strong display label for NAME or the current context."
  (let* ((name (or name (orbit-context-current-name)))
         (metadata (orbit-context--context-metadata name))
         (kind (plist-get metadata :kind))
         (base (pcase kind
                 ((or 'edit-project 'git-project 'files-root)
                  (format "%s %s"
                          (orbit-context--kind-display-name kind)
                          (or (plist-get metadata :group) name)))
                 (_ (orbit-context--kind-display-name kind))))
         (hint (orbit-context--related-hint name)))
    (if hint
        (format "%s · %s" base hint)
      base)))

(defun orbit-context-header-label (&optional name)
  "Return a header-line label for NAME or the current context."
  (orbit-context-modeline-label name))

(defun orbit-context--metadata-alist ()
  "Return serialized metadata for all contexts."
  (let (entries)
    (maphash (lambda (key value)
               (push (cons key value) entries))
             orbit-context--metadata)
    (nreverse entries)))

(defun orbit-context--restore-metadata (entries)
  "Restore context metadata from ENTRIES."
  (setq orbit-context--metadata (make-hash-table :test 'equal))
  (dolist (entry entries)
    (puthash (car entry) (cdr entry) orbit-context--metadata)))

(defun orbit-context--history-push (items item)
  "Return ITEMS with ITEM moved to the front and trimmed."
  (seq-take (cons item (delete item (copy-sequence items)))
            orbit-context--history-limit))

(defun orbit-context--history-buffer-names (name)
  "Return recent owned buffer names for context NAME."
  (copy-sequence
   (or (plist-get (orbit-context--context-metadata name) :history-buffers)
       '())))

(defun orbit-context--history-buffers (name)
  "Return live recent owned buffers for context NAME."
  (delq nil (mapcar #'get-buffer (orbit-context--history-buffer-names name))))

(defun orbit-context--recent-file-paths (name)
  "Return recent file paths for context NAME."
  (copy-sequence
   (or (plist-get (orbit-context--context-metadata name) :recent-files)
       '())))

(defun orbit-context--record-buffer-history (name buffer)
  "Record owned BUFFER in context NAME history."
  (when (and name
             (buffer-live-p buffer)
             (orbit-context--owned-buffer-p buffer name))
    (orbit-context--metadata-update
     name
     (lambda (metadata)
       (let ((metadata (plist-put metadata
                                  :history-buffers
                                  (orbit-context--history-push
                                   (or (plist-get metadata :history-buffers) '())
                                   (buffer-name buffer)))))
         (if-let* ((file (orbit-context--buffer-file buffer)))
             (plist-put metadata
                        :recent-files
                        (orbit-context--history-push
                         (or (plist-get metadata :recent-files) '())
                         file))
           metadata))))))

(defun orbit-context--record-current-buffer-history ()
  "Record current owned buffer into active context history."
  (when-let* ((name (orbit-context-current-name))
              ((not (minibufferp (current-buffer)))))
    (orbit-context--record-buffer-history name (current-buffer))))

(defun orbit-context--window-buffer-names ()
  "Return the buffer names visible in the selected frame's root window."
  (delete-dups
   (mapcar #'buffer-name
           (mapcar #'window-buffer
                   (window-list nil 'nomini)))))

(defun orbit-context--layout-buffer-p (buffer)
  "Return non-nil when BUFFER should participate in saved layout state."
  (not (memq (plist-get (orbit-context-buffer-policy buffer) :policy)
             '(:utility :ignore))))

(defun orbit-context-save-layout (&optional name)
  "Save the current frame layout for context NAME.
When NAME is nil, use the active context."
  (interactive)
  (when-let* ((name (or name (orbit-context-current-name))))
    (let* ((metadata (copy-sequence (orbit-context--context-metadata name)))
           (state (window-state-get (frame-root-window) t))
           (buffers (seq-filter
                     (lambda (buffer-name)
                       (when-let* ((buffer (get-buffer buffer-name)))
                         (orbit-context--layout-buffer-p buffer)))
                     (orbit-context--window-buffer-names)))
           (selected-buffer (window-buffer (selected-window)))
           (primary (and (orbit-context--layout-buffer-p selected-buffer)
                         (buffer-name selected-buffer))))
      (orbit-context--set-context-metadata
       name
       (plist-put
        (plist-put
         (plist-put metadata :window-state state)
         :layout-buffers buffers)
        :primary-buffer primary)))))

(defun orbit-context-clear-layout (&optional name)
  "Clear any saved layout for context NAME or the current context."
  (interactive)
  (when-let* ((name (or name (orbit-context-current-name))))
    (let ((metadata (copy-sequence (orbit-context--context-metadata name))))
      (orbit-context--set-context-metadata
       name
       (plist-put
        (plist-put
         (plist-put metadata :window-state nil)
         :layout-buffers nil)
        :primary-buffer nil)))))

(defun orbit-context-restore-layout (&optional name)
  "Restore the saved layout for context NAME or the current context.
Return non-nil when a saved layout was restored."
  (interactive)
  (when-let* ((name (or name (orbit-context-current-name)))
              (metadata (orbit-context--context-metadata name))
              (state (plist-get metadata :window-state))
              (buffer-names (plist-get metadata :layout-buffers))
              (live-buffers (seq-filter #'get-buffer buffer-names)))
    (when live-buffers
      (condition-case nil
          (progn
            (delete-other-windows)
            (window-state-put state (frame-root-window) 'safe)
            (let* ((primary-name (plist-get metadata :primary-buffer))
                   (primary-buffer (and primary-name (get-buffer primary-name)))
                   (primary-window (and primary-buffer
                                        (get-buffer-window primary-buffer t))))
              (cond
               (primary-window
                (select-window primary-window))
               ((and (buffer-live-p primary-buffer)
                     (orbit-context--owned-buffer-p primary-buffer name))
                (switch-to-buffer primary-buffer))
               ((when-let* ((owned (orbit-context--first-owned-buffer name)))
                  (switch-to-buffer owned)
                  t))))
            t)
        (error nil)))))

(defun orbit-context--mark-buffer (buffer role &optional root context-name)
  "Mark BUFFER with orbit context ROLE, optional ROOT, and CONTEXT-NAME."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq-local orbit-context--buffer-role role
                  orbit-context--buffer-root root
                  orbit-context--buffer-context-name context-name))))

(defun orbit-context--directory-name (dir)
  "Return the final directory name component of DIR."
  (file-name-nondirectory (directory-file-name dir)))

(defun orbit-context--edit-context-name (root)
  "Return the edit context name for ROOT."
  (format "edit/%s" (orbit-context--directory-name root)))

(defun orbit-context--files-context-name (root)
  "Return the files context name for ROOT."
  (format "files/%s" (orbit-context--directory-name root)))

(defun orbit-context--buffer-file (buffer)
  "Return BUFFER's visited file path, or nil."
  (buffer-local-value 'buffer-file-name buffer))

(defun orbit-context--buffer-default-directory (buffer)
  "Return BUFFER's `default-directory', or nil."
  (buffer-local-value 'default-directory buffer))

(defun orbit-context--buffer-role (buffer)
  "Return BUFFER's orbit context role."
  (buffer-local-value 'orbit-context--buffer-role buffer))

(defun orbit-context--buffer-root (buffer)
  "Return BUFFER's orbit context root marker."
  (buffer-local-value 'orbit-context--buffer-root buffer))

(defun orbit-context--buffer-context-name (buffer)
  "Return BUFFER's explicit orbit context attachment, or nil."
  (buffer-local-value 'orbit-context--buffer-context-name buffer))

(defun orbit-context--buffer-borrowed-contexts (buffer)
  "Return the list of context names BUFFER is borrowed into."
  (buffer-local-value 'orbit-context--borrowed-contexts buffer))

(defun orbit-context--borrowed-buffer-p (buffer name)
  "Return non-nil when BUFFER is explicitly borrowed into context NAME."
  (member name (orbit-context--buffer-borrowed-contexts buffer)))

(defun orbit-context--borrow-buffer-into-context (buffer name)
  "Add BUFFER to context NAME as an explicitly borrowed buffer."
  (when (buffer-live-p buffer)
    (with-perspective name
      (persp-set-buffer buffer))
    (with-current-buffer buffer
      (setq-local orbit-context--borrowed-contexts
                  (delete-dups (cons name orbit-context--borrowed-contexts)))))
  buffer)

(defun orbit-context--borrowed-buffers (name)
  "Return live buffers explicitly borrowed into context NAME."
  (seq-filter
   (lambda (buffer)
     (orbit-context--borrowed-buffer-p buffer name))
   (persp-get-buffers name)))

(defun orbit-context--unborrow-buffer-from-context (buffer name)
  "Remove BUFFER's borrowed attachment to context NAME."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq-local orbit-context--borrowed-contexts
                  (delete name orbit-context--borrowed-contexts))))
  buffer)

(defun orbit-context--buffer-derived-mode-p (buffer &rest modes)
  "Return non-nil when BUFFER is derived from any of MODES."
  (with-current-buffer buffer
    (apply #'derived-mode-p modes)))

(defun orbit-context--project-root ()
  "Return the current project root, or nil if not in a project."
  (when-let* ((project (project-current nil)))
    (project-root project)))

(defun orbit-context--project-root-for-file (file)
  "Return the project root for FILE, or nil."
  (let ((default-directory (file-name-directory file)))
    (orbit-context--project-root)))

(defun orbit-context--roam-file-p (file)
  "Return non-nil when FILE lives under `mod-roam-directory'."
  (when file
    (string-prefix-p (file-truename (file-name-as-directory (mod-roam-directory)))
                     (file-truename file))))

(defun orbit-context--edit-context-name-for-file (file)
  "Return the edit context name appropriate for FILE."
  (let ((project-root (orbit-context--project-root-for-file file)))
    (cond
     ((orbit-context--roam-file-p file)
      orbit-context-roam-edit-context-name)
     (project-root
      (orbit-context--edit-context-name project-root))
     (t
      orbit-context-loose-edit-context-name))))

(defun orbit-context--files-context-name-for-directory (dir)
  "Return the files context name appropriate for DIR."
  (let ((default-directory dir))
    (if-let* ((root (orbit-context--project-root)))
        (orbit-context--files-context-name root)
      (orbit-context--files-context-name dir))))

(defun orbit-context--ensure-files-context-metadata (root)
  "Ensure metadata exists for the files context rooted at ROOT."
  (let ((name (orbit-context--files-context-name root)))
    (orbit-context--set-context-metadata
     name
     (list :kind 'files-root
           :root root
           :group (orbit-context--directory-name root)))
    name))

(defun orbit-context--ensure-project-context-metadata (root)
  "Ensure metadata exists for ROOT's related project contexts."
  (let* ((name (orbit-context--directory-name root))
         (edit-name (format "edit/%s" name))
         (git-name (format "git/%s" name))
         (files-name (format "files/%s" name)))
    (orbit-context--set-context-metadata edit-name (list :kind 'edit-project :root root :group name))
    (orbit-context--set-context-metadata git-name (list :kind 'git-project :root root :group name))
    (orbit-context--set-context-metadata files-name (list :kind 'files-root :root root :group name))
    (list edit-name git-name files-name)))

(defun orbit-context--project-file-buffer-p (buffer root)
  "Return non-nil when BUFFER visits a file inside ROOT."
  (when-let* ((file (orbit-context--buffer-file buffer)))
    (string-prefix-p (file-truename root)
                     (file-truename file))))

(defun orbit-context--git-buffer-p (buffer root)
  "Return non-nil when BUFFER belongs to the Git context for ROOT."
  (or (eq (orbit-context--buffer-role buffer) 'git)
      (and (orbit-context--buffer-default-directory buffer)
           (string-prefix-p (file-truename root)
                            (file-truename (orbit-context--buffer-default-directory buffer)))
           (or (orbit-context--buffer-derived-mode-p buffer 'magit-mode 'magit-section-mode
                                                     'git-commit-mode 'diff-mode)
               (string-prefix-p "*" (buffer-name buffer))))))

(defun orbit-context--files-buffer-p (buffer root)
  "Return non-nil when BUFFER belongs to the files context for ROOT."
  (or (and (eq (orbit-context--buffer-role buffer) 'files)
           (equal (orbit-context--buffer-root buffer) root))
      (and (orbit-context--buffer-derived-mode-p buffer 'dired-mode)
           (orbit-context--buffer-default-directory buffer)
           (string-prefix-p (file-truename root)
                            (file-truename (orbit-context--buffer-default-directory buffer))))))

(defun orbit-context--notes-buffer-p (buffer)
  "Return non-nil when BUFFER belongs to the notes context."
  (eq (orbit-context--buffer-role buffer) 'notes))

(defun orbit-context--agenda-buffer-p (buffer)
  "Return non-nil when BUFFER belongs to the agenda context."
  (or (eq (orbit-context--buffer-role buffer) 'agenda)
      (orbit-context--buffer-derived-mode-p buffer 'org-agenda-mode)))

(defun orbit-context--scratch-buffer-p (buffer)
  "Return non-nil when BUFFER belongs to the scratch context."
  (or (eq (orbit-context--buffer-role buffer) 'scratch)
      (equal (buffer-name buffer) "*scratch*")))

(defun orbit-context--loose-file-buffer-p (buffer)
  "Return non-nil when BUFFER is a loose non-roam file buffer."
  (when-let* ((file (orbit-context--buffer-file buffer)))
    (and (not (orbit-context--roam-file-p file))
         (not (orbit-context--project-root-for-file file)))))

(defun orbit-context--owned-buffer-reason (buffer name)
  "Return a short reason why BUFFER belongs to context NAME, or nil."
  (when (buffer-live-p buffer)
    (let* ((metadata (orbit-context--context-metadata name))
           (kind (plist-get metadata :kind))
           (root (plist-get metadata :root))
           (policy (orbit-context-buffer-policy buffer))
           (policy-kind (plist-get policy :policy))
           (policy-name (plist-get policy :name)))
      (cond
       ((memq policy-kind '(:ignore :utility))
        nil)
       ((and (eq policy-kind :local)
             (equal (orbit-context--buffer-context-name buffer) name))
        (format "local policy %s attached to %s" policy-name name))
       ((and (eq kind 'edit-project)
             root
             (orbit-context--project-file-buffer-p buffer root))
        (format "project file under %s" root))
       ((and (eq kind 'git-project)
             root
             (orbit-context--git-buffer-p buffer root))
        (format "git support buffer for %s" root))
       ((and (eq kind 'files-root)
             root
             (orbit-context--files-buffer-p buffer root))
        (format "file-management buffer rooted at %s" root))
       ((and (eq kind 'edit-roam)
             (when-let* ((file (orbit-context--buffer-file buffer)))
               (orbit-context--roam-file-p file)))
        "Org-roam file")
       ((and (eq kind 'edit-loose)
             (orbit-context--loose-file-buffer-p buffer))
        "loose non-project file")
       ((and (eq kind 'notes)
             (orbit-context--notes-buffer-p buffer))
        "notes-owned buffer")
       ((and (eq kind 'agenda)
             (orbit-context--agenda-buffer-p buffer))
        "agenda buffer")
       ((and (eq kind 'scratch)
             (orbit-context--scratch-buffer-p buffer))
        "scratch buffer")
       (t nil)))))

(defun orbit-context--owned-buffer-p (buffer name)
  "Return non-nil when BUFFER belongs to context NAME."
  (and (orbit-context--owned-buffer-reason buffer name) t))

(defun orbit-context-explain-buffer (&optional buffer name)
  "Return a plist explaining how BUFFER relates to context NAME.
When called interactively, use the current buffer and active context."
  (interactive)
  (let* ((buffer (or buffer (current-buffer)))
         (name (or name (orbit-context-current-name)))
         (policy (orbit-context-buffer-policy buffer))
         (borrowed (and name (orbit-context--borrowed-buffer-p buffer name)))
         (reason (and name (orbit-context--owned-buffer-reason buffer name)))
         (result
          (list :buffer (buffer-name buffer)
                :context name
                :policy (plist-get policy :policy)
                :policy-name (plist-get policy :name)
                :policy-description (plist-get policy :description)
                :borrowed borrowed
                :owned (and reason t)
                :reason (or reason
                            (and borrowed
                                 (format "borrowed into %s" name))
                            (and policy
                                 (format "matched %s policy %s"
                                         (plist-get policy :policy)
                                         (plist-get policy :name)))
                            "no matching ownership rule"))))
    (when (called-interactively-p 'interactive)
      (message "%s" result))
    result))

(defun orbit-context--owned-buffers (name)
  "Return live buffers owned by context NAME."
  (let* ((buffers (seq-filter (lambda (buffer)
                                (orbit-context--owned-buffer-p buffer name))
                              (persp-get-buffers name)))
         (history (orbit-context--history-buffers name))
         ordered)
    (dolist (buffer history)
      (when (memq buffer buffers)
        (push buffer ordered)
        (setq buffers (delq buffer buffers))))
    (nconc (nreverse ordered) buffers)))

(defun orbit-context--first-owned-buffer (name)
  "Return the first owned live buffer in context NAME."
  (car (orbit-context--owned-buffers name)))

(defun orbit-context--next-owned-buffer (name &optional current-buffer)
  "Return the next owned buffer in NAME after CURRENT-BUFFER."
  (let* ((current-buffer (or current-buffer (current-buffer)))
         (buffers (orbit-context--owned-buffers name)))
    (or (car (delq current-buffer buffers))
        (car buffers))))

(defun orbit-context--forget-borrowed-buffer (buffer name)
  "Forget BUFFER from context NAME when it does not belong there."
  (when (and (buffer-live-p buffer)
             (memq buffer (persp-get-buffers name))
             (not (orbit-context--owned-buffer-p buffer name)))
    (with-perspective name
      (persp-forget-buffer buffer))))

(defun orbit-context--save-current-layout-before-switch (target-name)
  "Save the current context layout before switching to TARGET-NAME."
  (let ((current-name (orbit-context-current-name)))
    (when (and current-name
               (not (equal current-name target-name)))
      (orbit-context-save-layout current-name))))

(defun orbit-context--settle-after-switch (target-name source-buffer &optional opener)
  "Restore or populate TARGET-NAME after a context switch.
SOURCE-BUFFER is forgotten from TARGET-NAME when it does not belong there.
When OPENER is non-nil, use it if TARGET-NAME has neither a restorable layout
nor an owned buffer."
  (let ((target-buffer (orbit-context--first-owned-buffer target-name)))
    (unless (orbit-context-restore-layout target-name)
      (cond
       ((buffer-live-p target-buffer)
        (switch-to-buffer target-buffer))
       (opener
        (funcall opener)))))
  (when-let* ((current (current-buffer)))
    (orbit-context--record-buffer-history target-name current))
  (orbit-context--forget-borrowed-buffer source-buffer target-name))

(defun orbit-context--switch-owned (name &optional opener)
  "Switch to context NAME and keep the visible buffer destination-owned.
When OPENER is non-nil, call it if NAME has no owned buffers yet."
  (let ((source-buffer (current-buffer)))
    (orbit-context--save-current-layout-before-switch name)
    (orbit-context--switch-or-create name)
    (orbit-context--settle-after-switch name source-buffer opener)))

(defun orbit-context--ensure-context-exists (name metadata)
  "Ensure context NAME exists and is associated with METADATA."
  (orbit-context--set-context-metadata name metadata)
  (unless (orbit-context--exists-p name)
    (save-window-excursion
      (persp-new name)))
  name)

(defun orbit-context--edit-context-empty-p (name root)
  "Return non-nil when edit context NAME has no meaningful project buffers."
  (let ((metadata (orbit-context--context-metadata name)))
    (orbit-context--set-context-metadata name
                                         (plist-put metadata :root root))
    (null (orbit-context--owned-buffers name))))

(defun orbit-context--existing-context-names ()
  "Return the existing context names."
  (sort (copy-sequence (persp-names)) #'string-lessp))

(defun orbit-context--read-known-project-root ()
  "Prompt for one of the known project roots."
  (let ((projects (project-known-project-roots)))
    (unless projects
      (user-error "No known projects available"))
    (completing-read "Project: " projects nil t)))

(defun orbit-context--select-project ()
  "Return the selected project as a plist with `:root' and `:name'."
  (let* ((root (or (orbit-context--project-root)
                   (orbit-context--read-known-project-root)))
         (name (orbit-context--directory-name root)))
    (list :root root :name name)))

(add-hook 'post-command-hook #'orbit-context--record-current-buffer-history)

(orbit-context-register-buffer-policy
 'help
 :utility
 (lambda (buffer)
   (or (with-current-buffer buffer
         (derived-mode-p 'help-mode))
       (string-match-p "\\`\\*\\(?:Help\\|Apropos\\|info\\)\\*" (buffer-name buffer))))
 "Route help-style buffers to utility space.")

(orbit-context-register-buffer-policy
 'warnings
 :utility
 (lambda (buffer)
   (member (buffer-name buffer) '("*Warnings*" "*Messages*")))
 "Ignore warning and message buffers for context ownership.")

(orbit-context-register-buffer-policy
 'compilation
 :local
 (lambda (buffer)
   (with-current-buffer buffer
     (derived-mode-p 'compilation-mode)))
 "Keep compilation buffers attached to the context they were started from.")

(orbit-context-register-buffer-policy
 'xref
 :local
 (lambda (buffer)
   (with-current-buffer buffer
     (derived-mode-p 'xref--xref-buffer-mode)))
 "Keep xref result buffers attached to the context they were opened from.")

(orbit-context-register-buffer-policy
 'occur
 :local
 (lambda (buffer)
   (with-current-buffer buffer
     (derived-mode-p 'occur-mode)))
 "Keep occur buffers attached to the context they were created from.")

(orbit-context-register-buffer-policy
 'magit
 :local
 (lambda (buffer)
   (with-current-buffer buffer
     (derived-mode-p 'magit-mode 'magit-section-mode 'git-commit-mode 'diff-mode)))
 "Keep Magit support buffers attached to the Git context that created them.")

(orbit-context-register-buffer-policy
 'utility-shell
 :utility
 (lambda (buffer)
   (with-current-buffer buffer
     (or (derived-mode-p 'eat-mode 'shell-mode 'eshell-mode 'term-mode 'vterm-mode)
         (string-match-p "\\`\\*eat" (buffer-name buffer))
         (string-match-p "\\`\\*shell\\*" (buffer-name buffer)))))
 "Treat utility shell buffers as utility-space buffers.")

(provide 'orbit-context-core)

;;; orbit-context-core.el ends here
