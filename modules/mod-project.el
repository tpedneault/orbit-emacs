;;; mod-project.el --- Project foundation -*- lexical-binding: t; -*-

(require 'project)

(declare-function consult-ripgrep "consult")
(declare-function orbit-context-open-project-editor "orbit-context")
(declare-function mod-search-project "mod-search")
(declare-function mod-search-project-replace-query "mod-search")

(defun mod-project-current ()
  "Return the current project or signal a user-facing error."
  (or (project-current)
      (user-error "Not in a project")))

(defun mod-project-root ()
  "Return the root directory of the current project."
  (project-root (mod-project-current)))

(defun mod-project-search ()
  "Search the current project with `consult-ripgrep'."
  (interactive)
  (if (fboundp 'mod-search-project)
      (mod-search-project)
    (consult-ripgrep (mod-project-root))))

(defun mod-project-replace (from to)
  "Query-replace regexp FROM with TO across the current project."
  (interactive
   (let ((query-replace-read-from-regexp-default 'find-tag-default-as-regexp))
     (pcase-let ((`(,from ,to)
                  (query-replace-read-args "Project query replace (regexp)" t t)))
       (list from to))))
  (if (fboundp 'mod-search-project-replace-query)
      (mod-search-project-replace-query from to)
    (let ((default-directory (mod-project-root)))
      (project-query-replace-regexp from to))))

(defun mod-project-add (directory)
  "Remember DIRECTORY as a known project using the built-in project list."
  (interactive "DProject directory: ")
  (let* ((expanded (expand-file-name directory))
         (default-directory expanded)
         (project (project-current nil expanded)))
    (unless project
      (user-error "Not a recognized project: %s" expanded))
    (project-remember-project project)
    (message "Added project: %s" (project-root project))))

(defun mod-project-forget ()
  "Forget a known project from the built-in project list."
  (interactive)
  (call-interactively #'project-forget-project))

(defun mod-project-switch ()
  "Switch to a project's edit context without showing the action menu."
  (interactive)
  (let* ((projects (project-known-project-roots)))
    (unless projects
      (user-error "No known projects available"))
    (let* ((root (completing-read "Project: " projects nil t))
           (project (list :root root
                          :name (file-name-nondirectory (directory-file-name root)))))
      (orbit-context-open-project-editor project))))

(setq project-switch-commands
      '((project-find-file "Find file")
        (mod-project-search "Search")
        (project-dired "Dired")))

(provide 'mod-project)

;;; mod-project.el ends here
