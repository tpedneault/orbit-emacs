;;; mod-tcl.el --- Minimal Tcl workflow foundation -*- lexical-binding: t; -*-

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

(defcustom mod-tcl-tclint-command "tclint"
  "Executable used to lint Tcl files."
  :type 'string)

(defcustom mod-tcl-tclfmt-command "tclfmt"
  "Executable used to format Tcl files."
  :type 'string)

(defcustom mod-tcl-ctags-command "ctags"
  "Executable used to rebuild the project TAGS file."
  :type 'string)

(defcustom mod-tcl-ctags-args
  '("-e" "-R" "--languages=Tcl"
    "--langmap=Tcl:+.tcl,.tm,.sdc,.xdc,.upf"
    "-f" "TAGS" ".")
  "Arguments passed to `mod-tcl-ctags-command' when rebuilding TAGS."
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

(defun mod-tcl--ensure-command (command)
  "Return COMMAND's executable path or signal an error."
  (or (executable-find command)
      (user-error "Command not found: %s" command)))

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
        (program (mod-tcl--ensure-command mod-tcl-tclint-command)))
    (mod-tcl--run-compilation program (list file) (file-name-directory file))))

(defun mod-tcl-format-file ()
  "Run tclfmt on the current file and replace the buffer with formatted output.

This assumes `tclfmt FILE' writes formatted Tcl to standard output. If your
local tclfmt uses a different CLI shape, customize `mod-tcl-tclfmt-command'."
  (interactive)
  (let* ((file (mod-tcl--current-file))
         (program (mod-tcl--ensure-command mod-tcl-tclfmt-command))
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

(defun mod-tcl-find-tag ()
  "Jump to a definition using the project's TAGS file."
  (interactive)
  (let ((tags-file (mod-tcl--project-tags-file)))
    (unless (file-exists-p tags-file)
      (user-error "No TAGS file found at %s" tags-file))
    (visit-tags-table tags-file t)
    (if-let ((symbol (thing-at-point 'symbol t)))
        (xref-find-definitions symbol)
      (call-interactively #'find-tag))))

(defun mod-tcl-rebuild-tags ()
  "Rebuild the project-local TAGS file for Tcl sources."
  (interactive)
  (let ((root (mod-tcl--project-root))
        (program (mod-tcl--ensure-command mod-tcl-ctags-command)))
    (mod-tcl--run-compilation program mod-tcl-ctags-args root)
    (when-let ((tags-file (expand-file-name "TAGS" root)))
      (when (file-exists-p tags-file)
        (visit-tags-table tags-file t)))))

(defalias 'mod-tcl-show-output #'mod-tcl--display-output-buffer)

(provide 'mod-tcl)

;;; mod-tcl.el ends here
