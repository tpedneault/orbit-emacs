;;; mod-tcl.el --- Minimal Tcl workflow foundation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'compile)
(require 'etags)
(require 'project)
(require 'subr-x)
(require 'xref)

(defgroup mod-tcl nil
  "Minimal Tcl workflow helpers."
  :group 'tools)

(defcustom mod-tcl-output-buffer-name "*tcl-tools*"
  "Shared output buffer name for Tcl tool commands."
  :type 'string)

(defcustom mod-tcl-ctags-args
  '("-e" "-R" "--languages=Tcl"
    "--map-Tcl=+.tcl"
    "--map-Tcl=+.tm"
    "--map-Tcl=+.sdc"
    "--map-Tcl=+.xdc"
    "--map-Tcl=+.upf"
    "-f" "TAGS" ".")
  "Arguments passed to the ctags program when rebuilding TAGS."
  :type '(repeat string))

(defun mod-tcl--project-root ()
  "Return the current project root or signal a user-facing error."
  (if-let ((project (project-current nil)))
      (project-root project)
    (user-error "Not in a project")))

(defun mod-tcl--current-file ()
  "Return the current file path or signal a user-facing error."
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (unless (derived-mode-p 'tcl-mode)
    (user-error "Current buffer is not in tcl-mode"))
  (when (buffer-modified-p)
    (save-buffer))
  buffer-file-name)

(defun mod-tcl--ensure-program (program fallback-name)
  "Return PROGRAM or resolve FALLBACK-NAME, otherwise signal an error."
  (or program
      (user-error "Command not found: %s" fallback-name)))

(defun mod-tcl-ctags-program ()
  "Return the configured ctags program for Tcl TAGS generation."
  (mod-tcl--ensure-program
   (or orbit-user-ctags-program
       (executable-find "ctags"))
   "ctags"))

(defun mod-tcl-tclint-program ()
  "Return the configured tclint program."
  (mod-tcl--ensure-program
   (or orbit-user-tclint-program
       (executable-find "tclint"))
   "tclint"))

(defun mod-tcl-tclfmt-program ()
  "Return the configured tclfmt program."
  (mod-tcl--ensure-program
   (or orbit-user-tclfmt-program
       (executable-find "tclfmt"))
   "tclfmt"))

(defun mod-tcl--output-buffer ()
  "Return the shared Tcl tool output buffer."
  (get-buffer-create mod-tcl-output-buffer-name))

(defun mod-tcl--display-output-buffer ()
  "Display the shared Tcl tool output buffer."
  (interactive)
  (let ((buffer (mod-tcl--output-buffer)))
    (unless (buffer-live-p buffer)
      (user-error "No Tcl tool output buffer available"))
    (pop-to-buffer buffer)))

(defun mod-tcl--write-output (title lines &optional errorp)
  "Write TITLE and LINES to the shared output buffer.
When ERRORP is non-nil, keep point at the top and display the buffer."
  (with-current-buffer (mod-tcl--output-buffer)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert title "\n\n")
      (dolist (line lines)
        (insert line "\n"))
      (goto-char (point-min))
      (special-mode)))
  (when errorp
    (mod-tcl--display-output-buffer)))

(defun mod-tcl--compilation-command (program args)
  "Build a shell-safe command string from PROGRAM and ARGS."
  (string-join (mapcar #'shell-quote-argument (cons program args)) " "))

(defun mod-tcl--run-compilation (program args directory)
  "Run PROGRAM with ARGS in DIRECTORY using the shared compilation buffer."
  (let ((command (mod-tcl--compilation-command program args))
        (default-directory directory)
        (compilation-buffer-name-function (lambda (_) mod-tcl-output-buffer-name)))
    (compilation-start command 'compilation-mode (lambda (_) mod-tcl-output-buffer-name))))

(defun mod-tcl-lint-file ()
  "Run tclint on the current file."
  (interactive)
  (let ((file (mod-tcl--current-file))
        (program (mod-tcl-tclint-program)))
    (mod-tcl--run-compilation program (list file) (file-name-directory file))))

(defun mod-tcl-format-file ()
  "Run tclfmt on the current file and replace the buffer with formatted output.

This assumes `tclfmt FILE' writes formatted Tcl to standard output. If your
local tclfmt uses a different CLI shape, set `orbit-user-tclfmt-program'."
  (interactive)
  (let* ((file (mod-tcl--current-file))
         (program (mod-tcl-tclfmt-program))
         (output (generate-new-buffer " *tclfmt-output*"))
         (errors (generate-new-buffer " *tclfmt-errors*"))
         (coding-system-for-read 'utf-8)
         (coding-system-for-write 'utf-8)
         (status nil))
    (unwind-protect
        (progn
          (setq status (call-process program nil (list output errors) nil file))
          (cond
           ((not (eq status 0))
            (mod-tcl--write-output
             (format "tclfmt failed for %s" (file-name-nondirectory file))
             (split-string
              (with-current-buffer errors
                (buffer-substring-no-properties (point-min) (point-max)))
              "\n" t)
             t)
            (user-error "tclfmt failed"))
           ((with-current-buffer output (= (buffer-size) 0))
            (mod-tcl--write-output
             (format "tclfmt returned no output for %s" (file-name-nondirectory file))
             (list "No formatted output was returned."
                   "If your local tclfmt edits files in place, adjust the command wrapper in mod-tcl.el.")
             t)
            (message "tclfmt returned no output"))
           (t
            (let ((point-pos (point)))
              (replace-buffer-contents output)
              (save-buffer)
              (goto-char (min point-pos (point-max))))
            (mod-tcl--write-output
             (format "tclfmt %s" (file-name-nondirectory file))
             (list "Formatting completed successfully."))
            (message "Formatted %s" (file-name-nondirectory file)))))
      (kill-buffer output)
      (kill-buffer errors))))

(defun mod-tcl--project-tags-file ()
  "Return the current project's TAGS file path."
  (expand-file-name "TAGS" (mod-tcl--project-root)))

(defun mod-tcl--visit-project-tags-table ()
  "Visit the current project's TAGS file and return its path."
  (let ((tags-file (mod-tcl--project-tags-file)))
    (unless (file-exists-p tags-file)
      (user-error "No TAGS file found at %s" tags-file))
    (visit-tags-table tags-file t)
    tags-file))

(defun mod-tcl--symbol-at-point ()
  "Return the Tcl symbol at point or signal a user-facing error."
  (or (thing-at-point 'symbol t)
      (user-error "No symbol at point")))

(defun mod-tcl--fallback-tag-name (symbol)
  "Return the unqualified fallback tag name for SYMBOL."
  (car (last (split-string symbol "::" t))))

(defun mod-tcl--lookup-variants (symbol)
  "Return ordered tag lookup variants for SYMBOL."
  (let ((variants (list symbol)))
    (when (string-prefix-p "::" symbol)
      (push (string-remove-prefix "::" symbol) variants))
    (when (and (string-match-p "::" symbol)
               (not (string-prefix-p "::" symbol)))
      (push (concat "::" symbol) variants))
    (nreverse (cl-remove-duplicates variants :test #'equal))))

(defun mod-tcl--tag-matches (tag)
  "Return exact tag matches for TAG from the active TAGS table."
  (cl-remove-if-not
   (lambda (candidate) (string= candidate tag))
   (all-completions tag (tags-completion-table))))

(defun mod-tcl--find-tag-exact (tag)
  "Find TAG only when it exists exactly in the active TAGS table."
  (when (mod-tcl--tag-matches tag)
    (find-tag tag)
    t))

(defun mod-tcl--find-tag-with-fallbacks (symbol)
  "Find SYMBOL using exact namespace variants, then safe fallback names."
  (or (cl-some #'mod-tcl--find-tag-exact (mod-tcl--lookup-variants symbol))
      (let ((fallback (mod-tcl--fallback-tag-name symbol)))
        (when (= (length (mod-tcl--tag-matches fallback)) 1)
          (mod-tcl--find-tag-exact fallback)))))

(defun mod-tcl-find-tag ()
  "Jump to a definition using the project's TAGS file."
  (interactive)
  (mod-tcl--visit-project-tags-table)
  (let ((symbol (mod-tcl--symbol-at-point)))
    (unless (mod-tcl--find-tag-with-fallbacks symbol)
      (user-error "No TAGS definition found for: %s" symbol))))

(defun mod-tcl-rebuild-tags ()
  "Rebuild the project-local TAGS file for Tcl sources."
  (interactive)
  (let ((root (mod-tcl--project-root))
        (program (mod-tcl-ctags-program)))
    (mod-tcl--run-compilation program mod-tcl-ctags-args root)
    (when-let ((tags-file (expand-file-name "TAGS" root)))
      (when (file-exists-p tags-file)
        (visit-tags-table tags-file t)))))

(defalias 'mod-tcl-show-output #'mod-tcl--display-output-buffer)

(provide 'mod-tcl)

;;; mod-tcl.el ends here
