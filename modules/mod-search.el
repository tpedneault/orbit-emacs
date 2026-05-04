;;; mod-search.el --- Search and replace workflow -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'project)
(require 'subr-x)

(declare-function consult-find "consult" (dir &optional initial))
(declare-function consult-line "consult" (&optional initial start))
(declare-function consult-ripgrep "consult" (&optional dir initial))

(defconst mod-search-consult-ripgrep-default-args
  "rg --null --line-buffered --color=never --max-columns=1000 --path-separator / --smart-case --no-heading --line-number . -e ARG OPTS"
  "Fallback Consult ripgrep argument string when Consult is not fully loaded yet.")

(defvar consult-ripgrep-args mod-search-consult-ripgrep-default-args)

(defconst mod-search-rg-program "rg"
  "Preferred ripgrep executable for search and replace helpers.")

(defun mod-search--rg-installed-p ()
  "Return non-nil when ripgrep is available."
  (executable-find mod-search-rg-program))

(defun mod-search--require-rg ()
  "Signal a clear error when ripgrep is unavailable."
  (unless (mod-search--rg-installed-p)
    (user-error "ripgrep is not installed (install rg to use project search/replace)")))

(defun mod-search--project-root ()
  "Return the current project root, or nil outside a project."
  (when-let* ((project (project-current nil)))
    (project-root project)))

(defun mod-search-root ()
  "Return the preferred search root for the current context."
  (or (mod-search--project-root)
      default-directory))

(defun mod-search--consult-ripgrep-args (glob)
  "Return ripgrep arguments for Consult, optionally scoped by GLOB."
  (let ((base (or (and (boundp 'consult-ripgrep-args)
                       consult-ripgrep-args)
                  mod-search-consult-ripgrep-default-args)))
    (if (string-empty-p glob)
        base
    (string-join
     (list base
           "--glob"
           (shell-quote-argument glob))
     " "))))

(defun mod-search-project ()
  "Search the current project with live ripgrep results."
  (interactive)
  (mod-search--require-rg)
  (consult-ripgrep (mod-search-root)))

(defun mod-search-directory ()
  "Search the current directory with live ripgrep results."
  (interactive)
  (mod-search--require-rg)
  (consult-ripgrep default-directory))

(defun mod-search-buffer ()
  "Search the current buffer."
  (interactive)
  (consult-line))

(defun mod-search-project-at-point ()
  "Search the current project for the symbol at point."
  (interactive)
  (mod-search--require-rg)
  (consult-ripgrep (mod-search-root) (thing-at-point 'symbol t)))

(defun mod-search-buffer-at-point ()
  "Search the current buffer for the symbol at point."
  (interactive)
  (consult-line (thing-at-point 'symbol t)))

(defun mod-search-project-files ()
  "Find a file by name under the current project or directory root."
  (interactive)
  (consult-find (mod-search-root)))

(defun mod-search--read-regexp ()
  "Read a project search regexp."
  (read-regexp "Search regexp (ripgrep / Emacs regexp): "))

(defun mod-search--read-replacement ()
  "Read a regexp replacement string."
  (read-string "Replacement text (regexp replace): "))

(defun mod-search--read-glob ()
  "Read an optional file glob."
  (read-string
   "File glob (empty = all rg-matched files, e.g. *.el, src/**/*.py, tests/**/*.tcl): "))

(defun mod-search--display-glob (glob)
  "Return a user-facing description for GLOB."
  (if (string-empty-p glob)
      "<all rg-matched files>"
    glob))

(defun mod-search--preview-matches (root regexp glob)
  "Preview REGEXP matches under ROOT, optionally limited by GLOB."
  (let ((consult-ripgrep-args (mod-search--consult-ripgrep-args glob)))
    (consult-ripgrep root regexp)))

(defun mod-search--rg-files-with-matches (root regexp glob)
  "Return files under ROOT with matches for REGEXP, optionally filtered by GLOB."
  (mod-search--require-rg)
  (with-temp-buffer
    (let ((default-directory root)
          (args (append (list "--files-with-matches" "--null" "--regexp" regexp)
                        (unless (string-empty-p glob)
                          (list "--glob" glob))
                        (list "."))))
      (pcase (apply #'process-file mod-search-rg-program nil t nil args)
        (0 (split-string (buffer-string) "\0" t))
        (1 nil)
        (status
         (user-error "ripgrep failed (%s): %s"
                     status
                     (string-trim (buffer-string))))))))

(defun mod-search--replace-buffer-all (buffer regexp replacement)
  "Replace REGEXP with REPLACEMENT throughout BUFFER.
Return the number of replacements made."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-min))
      (let ((count 0)
            (case-fold-search nil))
        (while (re-search-forward regexp nil t)
          (replace-match replacement nil nil)
          (setq count (1+ count)))
        count))))

(defun mod-search--replace-files-all (root files regexp replacement)
  "Replace REGEXP with REPLACEMENT in FILES under ROOT.
Return a cons cell of (FILES-CHANGED . REPLACEMENTS)."
  (let ((default-directory root)
        (files-changed 0)
        (replacements 0))
    (dolist (relative files)
      (let* ((file (expand-file-name relative root))
             (existing-buffer (get-file-buffer file))
             (buffer (or existing-buffer
                         (find-file-noselect file))))
        (with-current-buffer buffer
          (let ((count (mod-search--replace-buffer-all buffer regexp replacement)))
            (when (> count 0)
              (setq files-changed (1+ files-changed))
              (setq replacements (+ replacements count))
              (save-buffer))))
        (unless existing-buffer
          (kill-buffer buffer))))
    (cons files-changed replacements)))

(defun mod-search-project-replace-query (regexp replacement)
  "Query-replace REGEXP with REPLACEMENT across the current project."
  (interactive
   (list (mod-search--read-regexp)
         (mod-search--read-replacement)))
  (let ((root (mod-search--project-root)))
    (unless root
      (user-error "No project root available for query replace"))
    (let ((default-directory root))
      (project-query-replace-regexp regexp replacement))))

(defun mod-search-project-replace-all (regexp replacement glob)
  "Replace REGEXP with REPLACEMENT across project files matching GLOB.
Shows a ripgrep preview first, then asks for explicit confirmation."
  (interactive
   (list (mod-search--read-regexp)
         (mod-search--read-replacement)
         (mod-search--read-glob)))
  (let* ((root (mod-search-root))
         (display-root (abbreviate-file-name root)))
    (mod-search--require-rg)
    (mod-search--preview-matches root regexp glob)
    (let ((files (mod-search--rg-files-with-matches root regexp glob)))
      (if (not files)
          (message "No matching files for %s under %s (%s)"
                   regexp
                   display-root
                   (mod-search--display-glob glob))
        (when (yes-or-no-p
               (format
                (concat
                 "Replace all matches?\n"
                 "search regexp: %s\n"
                 "replacement: %s\n"
                 "root: %s\n"
                 "glob: %s\n"
                 "candidate files: %d\n")
                regexp
                replacement
                display-root
                (mod-search--display-glob glob)
                (length files)))
          (pcase-let ((`(,files-changed . ,replacements)
                       (mod-search--replace-files-all root files regexp replacement)))
            (message "Replaced %d matches across %d files under %s"
                     replacements
                     files-changed
                     display-root)))))))

(provide 'mod-search)

;;; mod-search.el ends here
