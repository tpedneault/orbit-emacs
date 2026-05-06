;;; orbit-context-ui.el --- Interactive context UI -*- lexical-binding: t; -*-

(require 'transient)

(defun orbit-context--display-borrowed-buffer (buffer)
  "Display borrowed BUFFER side by side in the current context."
  (let ((window (if (one-window-p)
                    (split-window-right)
                  (next-window (selected-window) 'no-minibuf))))
    (select-window window)
    (switch-to-buffer buffer)
    buffer))

(defun orbit-context-switch (&optional name)
  "Switch to an existing context or create one by NAME."
  (interactive)
  (let* ((target
          (or name
              (completing-read "Switch to context: "
                               (orbit-context--existing-context-names)
                               nil nil nil nil (orbit-context-current-name))))
         (source-buffer (current-buffer)))
    (when (string-empty-p target)
      (user-error "Context name cannot be empty"))
    (orbit-context--save-current-layout-before-switch target)
    (orbit-context--switch-or-create target)
    (orbit-context--settle-after-switch target source-buffer)))

(defun orbit-context-buffers ()
  "Switch to a buffer owned by the current context."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (buffers (orbit-context--owned-buffers name)))
    (unless buffers
      (user-error "No owned buffers in %s" name))
    (switch-to-buffer
     (get-buffer
      (completing-read "Context buffer: "
                       (mapcar #'buffer-name buffers)
                       nil t)))))

(defun orbit-context-last-buffer ()
  "Switch to the previous owned buffer in the current context."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (target (orbit-context--next-owned-buffer name (current-buffer))))
    (unless (buffer-live-p target)
      (user-error "No alternate owned buffer in %s" name))
    (switch-to-buffer target)
    (message "Switched to %s" (buffer-name target))))

(defun orbit-context-bury-buffer ()
  "Bury the current buffer and stay inside the current context when possible."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (current (current-buffer))
         (target (orbit-context--next-owned-buffer name current)))
    (bury-buffer current)
    (cond
     ((and (buffer-live-p target)
           (not (eq target current)))
      (switch-to-buffer target))
     ((not (eq current (window-buffer (selected-window))))
      nil)
     (t
      (message "No alternate owned buffer in %s" name)))))

(defun orbit-context-recent-files ()
  "Open a recent file associated with the current context."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (files (seq-filter #'file-exists-p
                            (orbit-context--recent-file-paths name))))
    (unless files
      (user-error "No recent files recorded for %s" name))
    (orbit-context-open-path
     (completing-read "Recent context file: " files nil t))))

(defun orbit-context-find-file ()
  "Open a file rooted in the current context when possible."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (root (orbit-context-current-root name))
         (default-directory (or root default-directory))
         (path (read-file-name "Find file in context: " default-directory nil nil)))
    (orbit-context-open-path path)))

(defun orbit-context-explain-current-buffer ()
  "Explain how the current buffer relates to the active context."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (explanation (orbit-context-explain-buffer (current-buffer) name)))
    (message "%s" explanation)))

(defun orbit-context-describe-current ()
  "Describe the current context in a help-style buffer."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (metadata (orbit-context--context-metadata name))
         (owned (mapcar #'buffer-name (orbit-context--owned-buffers name)))
         (borrowed (mapcar #'buffer-name (orbit-context--borrowed-buffers name)))
         (layout-buffers (or (plist-get metadata :layout-buffers) '()))
         (recent-files (orbit-context--recent-file-paths name))
         (history (orbit-context--history-buffer-names name))
         (related (orbit-context-related-names name))
         (buffer (get-buffer-create "*Orbit Context*")))
    (with-current-buffer buffer
      (setq buffer-read-only nil)
      (erase-buffer)
      (insert (format "Context: %s\n\n" name))
      (insert (format "Kind: %S\n" (orbit-context-current-kind name)))
      (insert (format "Group: %S\n" (orbit-context-current-group name)))
      (insert (format "Root: %S\n" (orbit-context-current-root name)))
      (insert (format "Related: %S\n" related))
      (insert (format "Saved layout: %s\n\n"
                      (if (plist-get metadata :window-state) "yes" "no")))
      (insert "Owned buffers:\n")
      (dolist (item owned)
        (insert (format "- %s\n" item)))
      (unless owned
        (insert "- none\n"))
      (insert "\nBorrowed buffers:\n")
      (dolist (item borrowed)
        (insert (format "- %s\n" item)))
      (unless borrowed
        (insert "- none\n"))
      (insert "\nHistory:\n")
      (dolist (item history)
        (insert (format "- %s\n" item)))
      (unless history
        (insert "- none\n"))
      (insert "\nRecent files:\n")
      (dolist (item recent-files)
        (insert (format "- %s\n" item)))
      (unless recent-files
        (insert "- none\n"))
      (insert "\nSaved layout buffers:\n")
      (dolist (item layout-buffers)
        (insert (format "- %s\n" item)))
      (unless layout-buffers
        (insert "- none\n"))
      (special-mode))
    (pop-to-buffer buffer)))

(defun orbit-context-move-buffer (name)
  "Move the current buffer into context NAME."
  (interactive
   (list (completing-read "Move buffer to context: "
                          (orbit-context--existing-context-names)
                          nil nil nil nil (orbit-context-current-name))))
  (let ((buffer (current-buffer))
        (source (orbit-context-current-name)))
    (orbit-context--switch-or-create name)
    (persp-set-buffer buffer)
    (switch-to-buffer buffer)
    (when (and source
               (not (equal source name)))
      (with-perspective source
        (persp-forget-buffer buffer)))
    (message "Moved %s to %s" (buffer-name buffer) name)))

(defun orbit-context-borrow-buffer (buffer)
  "Borrow an existing BUFFER into the current context for comparison."
  (interactive
   (list
    (get-buffer
     (completing-read
      "Borrow buffer: "
      (delete-dups
       (mapcar #'buffer-name
               (seq-filter #'buffer-live-p (buffer-list))))
      nil t nil nil (buffer-name (other-buffer (current-buffer) t))))))
  (let ((name (or (orbit-context-current-name)
                  (user-error "No active context"))))
    (unless (buffer-live-p buffer)
      (user-error "Buffer is not live"))
    (orbit-context--borrow-buffer-into-context buffer name)
    (orbit-context--display-borrowed-buffer buffer)
    (message "Borrowed %s into %s" (buffer-name buffer) name)))

(defun orbit-context-borrow-file (path)
  "Borrow file PATH into the current context for side-by-side viewing."
  (interactive "fBorrow file: ")
  (let ((name (or (orbit-context-current-name)
                  (user-error "No active context")))
        (buffer (find-file-noselect (expand-file-name path))))
    (orbit-context--borrow-buffer-into-context buffer name)
    (orbit-context--display-borrowed-buffer buffer)
    (message "Borrowed %s into %s" (buffer-name buffer) name)))

(defun orbit-context-unborrow-buffer ()
  "Remove the current buffer's borrowed attachment to the active context."
  (interactive)
  (let* ((buffer (current-buffer))
         (name (or (orbit-context-current-name)
                   (user-error "No active context"))))
    (unless (orbit-context--borrowed-buffer-p buffer name)
      (user-error "%s is not borrowed into %s" (buffer-name buffer) name))
    (orbit-context--unborrow-buffer-from-context buffer name)
    (persp-forget-buffer buffer)
    (message "Unborrowed %s from %s" (buffer-name buffer) name)))

(defun orbit-context-forget-buffer ()
  "Remove the current buffer from the current context without killing it."
  (interactive)
  (let ((buffer (current-buffer))
        (name (or (orbit-context-current-name)
                  (user-error "No active context"))))
    (persp-forget-buffer buffer)
    (message "Forgot %s from %s" (buffer-name buffer) name)))

(defun orbit-context-cleanup ()
  "Forget unrelated buffers from the current context."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (buffers (seq-filter #'buffer-live-p (persp-get-buffers name)))
         (removals (seq-filter (lambda (buffer)
                                 (not (orbit-context--owned-buffer-p buffer name)))
                               buffers)))
    (if (null removals)
        (message "%s is already clean" name)
      (when (y-or-n-p
             (format "Forget %d unrelated buffer(s) from %s? "
                     (length removals) name))
        (dolist (buffer removals)
          (persp-forget-buffer buffer))
        (message "Forgot %d buffer(s) from %s" (length removals) name)))))

(defun orbit-context-new ()
  "Create and switch to a new blank context."
  (interactive)
  (let ((name (read-string "New context name: ")))
    (when (string-empty-p name)
      (user-error "Context name cannot be empty"))
    (when (gethash name (perspectives-hash))
      (user-error "Context already exists: %s" name))
    (persp-switch name)
    (persp-switch-to-scratch-buffer)))

(defun orbit-context-delete ()
  "Delete an existing context."
  (interactive)
  (let ((name (orbit-context-current-name)))
    (call-interactively #'persp-kill)
    (when name
      (remhash name orbit-context--metadata))))

(defun orbit-context-rename ()
  "Rename the current context."
  (interactive)
  (let* ((old-name (or (orbit-context-current-name)
                       (user-error "No active context")))
         (metadata (gethash old-name orbit-context--metadata))
         (new-name (read-string "Rename context to: " old-name)))
    (when (string-empty-p new-name)
      (user-error "Context name cannot be empty"))
    (persp-rename new-name)
    (when metadata
      (remhash old-name orbit-context--metadata)
      (puthash new-name metadata orbit-context--metadata))))

(defun orbit-context-previous ()
  "Switch to the previous context."
  (interactive)
  (let ((source-name (orbit-context-current-name))
        (source-buffer (current-buffer)))
    (orbit-context-save-layout source-name)
    (persp-prev)
    (let ((target-name (orbit-context-current-name)))
      (unless (equal source-name target-name)
        (orbit-context--settle-after-switch target-name source-buffer)))))

(defun orbit-context-next ()
  "Switch to the next context."
  (interactive)
  (let ((source-name (orbit-context-current-name))
        (source-buffer (current-buffer)))
    (orbit-context-save-layout source-name)
    (persp-next)
    (let ((target-name (orbit-context-current-name)))
      (unless (equal source-name target-name)
        (orbit-context--settle-after-switch target-name source-buffer)))))

(defun orbit-context-project-suite (&optional project)
  "Ensure the related project contexts for PROJECT and land in its edit context."
  (interactive)
  (let* ((project (or project (orbit-context--select-project)))
         (root (plist-get project :root))
         (group (orbit-context--directory-name root)))
    (orbit-context--ensure-project-context-metadata root)
    (orbit-context--ensure-context-exists
     (format "edit/%s" group)
     (list :kind 'edit-project :root root :group group))
    (orbit-context--ensure-context-exists
     (format "git/%s" group)
     (list :kind 'git-project :root root :group group))
    (orbit-context--ensure-context-exists
     (format "files/%s" group)
     (list :kind 'files-root :root root :group group))
    (orbit-context-open-project-editor project)))

(defun orbit-context-notes-suite ()
  "Ensure the notes-related contexts and land in agenda."
  (interactive)
  (orbit-context--ensure-context-exists "notes" (list :kind 'notes))
  (orbit-context--ensure-context-exists "agenda" (list :kind 'agenda))
  (orbit-context--ensure-context-exists orbit-context-roam-edit-context-name (list :kind 'edit-roam))
  (orbit-context-agenda))

(defun orbit-context-related ()
  "Jump between contexts related to the current project or notes workflow."
  (interactive)
  (let* ((name (or (orbit-context-current-name)
                   (user-error "No active context")))
         (metadata (orbit-context--context-metadata name))
         (group (plist-get metadata :group))
         (root (plist-get metadata :root))
         (choices
          (cond
           (group
            (unless root
              (user-error "Current context has no related root metadata"))
            (orbit-context--ensure-project-context-metadata root))
           ((member (plist-get metadata :kind) '(notes agenda edit-roam))
            (list "agenda" "notes" orbit-context-roam-edit-context-name))
           (t
            (user-error "No related contexts for %s" name)))))
    (let ((target (completing-read "Related context: " choices nil t nil nil name)))
      (pcase target
        ("agenda" (orbit-context-agenda))
        ("notes" (orbit-context-notes))
        ((pred (lambda (value) (equal value orbit-context-roam-edit-context-name)))
         (orbit-context--switch-owned orbit-context-roam-edit-context-name))
        (_ (if (string-prefix-p "edit/" target)
               (orbit-context-open-project-editor
                (list :root root
                      :name (orbit-context--directory-name root)))
             (orbit-context--switch-owned
              target
              (pcase (plist-get (orbit-context--context-metadata target) :kind)
                ('git-project
                 (lambda ()
                   (let ((default-directory root))
                     (mod-git-status)
                     (orbit-context--mark-buffer (current-buffer) 'git root)
                     (delete-other-windows))))
                ('files-root
                 (lambda ()
                   (let ((default-directory root))
                     (mod-dired-here)
                     (orbit-context--mark-buffer (current-buffer) 'files root))))
                (_ nil)))))))))

(transient-define-prefix orbit-context-dispatch ()
  "Transient panel for orbit contexts."
  [["Open"
    ("e" "edit" orbit-context-editor)
    ("g" "git" orbit-context-git)
    ("f" "files" orbit-context-files)
    ("o" "notes" orbit-context-notes)
   ("a" "agenda" orbit-context-agenda)
   ("s" "scratch" orbit-context-scratch)]
   ["Move"
    ("m" "move buffer" orbit-context-move-buffer)
    ("y" "borrow buffer" orbit-context-borrow-buffer)
    ("B" "borrow file" orbit-context-borrow-file)
    ("u" "unborrow buffer" orbit-context-unborrow-buffer)
    ("k" "forget buffer" orbit-context-forget-buffer)]
   ["Operate"
    ("l" "last buffer" orbit-context-last-buffer)
    ("z" "bury buffer" orbit-context-bury-buffer)
    ("F" "find file" orbit-context-find-file)
    ("v" "recent files" orbit-context-recent-files)]
   ["Inspect"
    ("b" "context buffers" orbit-context-buffers)
    ("E" "explain buffer" orbit-context-explain-current-buffer)
    ("D" "describe context" orbit-context-describe-current)
    ("x" "switch" orbit-context-switch)
    ("r" "rename" orbit-context-rename)
    ("d" "delete" orbit-context-delete)]
   ["Hygiene"
    ("c" "cleanup" orbit-context-cleanup)]
   ["Related"
    ("p" "project suite" orbit-context-project-suite)
    ("n" "notes suite" orbit-context-notes-suite)
    ("R" "related" orbit-context-related)]])

(provide 'orbit-context-ui)

;;; orbit-context-ui.el ends here
