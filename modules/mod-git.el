;;; mod-git.el --- Git foundation -*- lexical-binding: t; -*-

(require 'subr-x)

;; Magit requires a newer `transient' than the one available in this Emacs.
(use-package transient
  :ensure t
  :commands (transient-define-prefix))

(use-package magit
  :ensure (:fetcher github
           :repo "magit/magit"
           :depth 1
           :main-file "lisp/magit.el"
           :files ("lisp/*.el"
                   "docs/magit.texi"
                   "docs/AUTHORS.md"
                   "LICENSE"
                   ("git-hooks" "git-hooks/*")))
  :commands (magit-status magit-log-current magit-blame-addition
             magit-dispatch magit-file-dispatch magit-diff
             magit-log-buffer-file magit-file-stage magit-file-unstage)
  :config
  (setq magit-diff-refine-hunk t           ; word-level diff in selected hunk
        magit-save-repository-buffers nil  ; don't auto-save before git ops (avoids triggering formatters)
        magit-revision-insert-related-refs nil)) ; faster commit view

(with-eval-after-load 'git-commit
  (setq git-commit-summary-max-length 50)  ; enforce 50-char subject line
  (add-hook 'git-commit-setup-hook
            (lambda ()
              (setq fill-column 72)         ; wrap body at 72 chars
              (when (fboundp 'evil-insert-state)
                (evil-insert-state)))))

(defun mod-git-status ()
  "Open Magit status for the current repository."
  (interactive)
  (call-interactively #'magit-status))

(defun mod-git-log ()
  "Open a compact Magit log entry point for the current repository."
  (interactive)
  (call-interactively #'magit-log-current))

(defun mod-git-blame ()
  "Start Magit blame for the current file."
  (interactive)
  (call-interactively #'magit-blame-addition))

(defun mod-git-log-file ()
  "Open a Magit log for the current buffer's file."
  (interactive)
  (call-interactively #'magit-log-buffer-file))

(defun mod-git-stage-file ()
  "Stage the current file via Magit."
  (interactive)
  (call-interactively #'magit-file-stage))

(defun mod-git-unstage-file ()
  "Unstage the current file via Magit."
  (interactive)
  (call-interactively #'magit-file-unstage))

(use-package diff-hl
  :ensure t
  :demand t
  :config
  (global-diff-hl-mode 1)
  (with-eval-after-load 'magit
    (add-hook 'magit-pre-refresh-hook  #'diff-hl-magit-pre-refresh)
    (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh)))

(defun mod-git--repository-root ()
  "Return the current Git repository root, or signal a clear error."
  (let* ((default-directory (or (and buffer-file-name
                                     (file-name-directory buffer-file-name))
                                default-directory))
         (root (string-trim
                (with-output-to-string
                  (with-current-buffer standard-output
                    (unless (zerop (process-file "git" nil t nil "rev-parse" "--show-toplevel"))
                      (user-error "Not in a Git repository")))))))
    (unless (and root (not (string-empty-p root)))
      (user-error "Not in a Git repository"))
    root))

(defun mod-git--default-revision ()
  "Return the current Git revision name for prompting."
  (let ((default-directory (mod-git--repository-root)))
    (string-trim
     (with-output-to-string
       (with-current-buffer standard-output
         (unless (zerop (process-file "git" nil t nil "rev-parse" "--abbrev-ref" "HEAD"))
           (user-error "Could not determine current Git revision")))))))

(defun mod-git--list-branches (root)
  "Return all local and remote branch names for the repo at ROOT."
  (let ((default-directory root)
        (raw (with-output-to-string
               (with-current-buffer standard-output
                 (process-file "git" nil t nil
                               "branch" "-a" "--format=%(refname:short)")))))
    (cl-remove-if #'string-empty-p (split-string raw "\n"))))

(defun mod-git--read-revision (root)
  "Prompt for a Git branch or revision in ROOT using completion."
  (let* ((branches (mod-git--list-branches root))
         (default (mod-git--default-revision))
         (prompt (if default
                     (format "Git revision (default %s): " default)
                   "Git revision: ")))
    (completing-read prompt branches nil nil nil nil default)))

(defun mod-git--relative-file-at-point (root)
  "Return the current buffer file relative to ROOT, when practical."
  (when (and buffer-file-name
             (string-prefix-p (file-truename root)
                              (file-truename buffer-file-name)))
    (file-relative-name buffer-file-name root)))

(defun mod-git--files-in-revision (revision root)
  "Return the tracked file list for REVISION under ROOT."
  (let ((default-directory root))
    (split-string
     (with-output-to-string
       (with-current-buffer standard-output
         (unless (zerop (process-file "git" nil t nil "ls-tree" "-r" "--name-only" revision))
           (user-error "Could not list files for Git revision: %s" revision))))
     "\n"
     t)))

(defun mod-git--read-revision-file (revision root)
  "Prompt for a file from REVISION under ROOT."
  (let* ((files (mod-git--files-in-revision revision root))
         (default-file (mod-git--relative-file-at-point root)))
    (unless files
      (user-error "No files found for Git revision: %s" revision))
    (completing-read
     (format "File in %s: " revision)
     files
     nil
     t
     nil
     nil
     default-file)))

(defun mod-git-find-file-from-revision (revision path)
  "Open PATH from Git REVISION in a read-only buffer."
  (interactive
   (let* ((root (mod-git--repository-root))
          (revision (mod-git--read-revision root)))
     (list revision
           (mod-git--read-revision-file revision root))))
  (let* ((root (mod-git--repository-root))
         (default-directory root)
         (buffer-name (format "*git:%s:%s*" revision path))
         (buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (unless (zerop (process-file "git" nil t nil "show" (format "%s:%s" revision path)))
          (user-error "Could not open %s from Git revision %s" path revision))
        (setq-local default-directory root)
        (setq-local buffer-file-name (expand-file-name path root))
        (set-auto-mode)
        (setq-local buffer-file-name nil)
        (setq-local mode-line-process nil)
        (setq-local buffer-read-only t)
        (view-mode 1)
        (set-buffer-modified-p nil)))
    (pop-to-buffer buffer)))

(provide 'mod-git)

;;; mod-git.el ends here
