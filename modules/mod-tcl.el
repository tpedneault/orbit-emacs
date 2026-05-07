;;; mod-tcl.el --- Minimal Tcl workflow foundation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'compile)
(require 'etags)
(require 'project)
(require 'subr-x)
(require 'xref)

(declare-function mod-tcl-docs-doxygen-config-file "mod-tcl-docs")
(declare-function mod-tcl-docs-completion-doc-buffer "mod-tcl-docs" (symbol))
(declare-function mod-tcl-docs-completion-entry "mod-tcl-docs" (symbol))
(declare-function mod-tcl-docs-completion-location "mod-tcl-docs" (symbol))
(declare-function mod-tcl-docs-completion-summary "mod-tcl-docs" (symbol))
(declare-function mod-snippets-setup-completion "mod-snippets")

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

(defconst mod-tcl-default-indent-width 3
  "Default indentation width for Tcl buffers.")

(defconst mod-tcl-default-fill-column 120
  "Default fill column for Tcl buffers.")

(defvar-local mod-tcl--symbol-highlight-regexp nil
  "Buffer-local regexp used for Tcl project symbol highlighting.")

(defvar mod-tcl--canonical-symbol-cache (make-hash-table :test #'equal)
  "Cache of canonical Tcl symbols keyed by project and file mtimes.")

(defconst mod-tcl--symbol-highlight-keywords
  '((mod-tcl--symbol-highlight-matcher
     (1 'font-lock-function-name-face keep)))
  "Font-lock keywords used for Tcl project symbol highlighting.")

(defun mod-tcl-indent-width ()
  "Return the preferred Tcl indentation width."
  (or orbit-user-tcl-indent-width mod-tcl-default-indent-width))

(defun mod-tcl-fill-column ()
  "Return the preferred Tcl fill column."
  (or orbit-user-tcl-fill-column
      orbit-user-fill-column
      mod-tcl-default-fill-column))

(defun mod-tcl-use-tabs-p ()
  "Return non-nil when Tcl buffers should indent with tabs."
  orbit-user-tcl-use-tabs)

(defun mod-tcl--resolve-override (override global-default)
  "Return OVERRIDE unless it is `inherit', otherwise GLOBAL-DEFAULT."
  (if (eq override 'inherit)
      global-default
    override))

(defun mod-tcl-enable-whitespace-p ()
  "Return non-nil when Tcl buffers should enable whitespace visibility."
  (mod-tcl--resolve-override
   orbit-user-tcl-enable-whitespace
   orbit-user-enable-whitespace))

(defun mod-tcl-enable-hl-line-p ()
  "Return non-nil when Tcl buffers should enable current-line highlighting."
  (mod-tcl--resolve-override
   orbit-user-tcl-enable-hl-line
   orbit-user-enable-hl-line))

(defun mod-tcl-enable-fill-column-indicator-p ()
  "Return non-nil when Tcl buffers should enable the fill-column indicator."
  (mod-tcl--resolve-override
   orbit-user-tcl-enable-fill-column-indicator
   orbit-user-enable-fill-column-indicator))

(defun mod-tcl--configure-editing-defaults ()
  "Apply Tcl editing defaults to the current buffer."
  (setq-local indent-tabs-mode (mod-tcl-use-tabs-p)
              tab-width (mod-tcl-indent-width)
              fill-column (mod-tcl-fill-column))
  (when (boundp 'tcl-indent-level)
    (setq-local tcl-indent-level (mod-tcl-indent-width)))
  (setq-local display-fill-column-indicator-column fill-column)
  (when (fboundp 'display-fill-column-indicator-mode)
    (display-fill-column-indicator-mode
     (if (mod-tcl-enable-fill-column-indicator-p) 1 -1)))
  (setq-local whitespace-style '(face tabs trailing))
  (when (fboundp 'whitespace-mode)
    (setq-local mod-ui--whitespace-visible (mod-tcl-enable-whitespace-p))
    (whitespace-mode (if (mod-tcl-enable-whitespace-p) 1 -1)))
  (when (fboundp 'hl-line-mode)
    (hl-line-mode (if (mod-tcl-enable-hl-line-p) 1 -1))))

(defun mod-tcl-enable-manual-folding ()
  "Enable hideshow folding for Tcl buffers."
  (hs-minor-mode 1))

(defun mod-tcl-toggle-fold ()
  "Toggle the hideshow fold at point."
  (interactive)
  (hs-toggle-hiding))

(defun mod-tcl--definition-start-line-p ()
  "Return non-nil when the current line starts a top-level Tcl definition."
  (and (= (car (syntax-ppss (line-beginning-position))) 0)
       (not (nth 4 (syntax-ppss (line-beginning-position))))
       (save-excursion
         (let ((line-end (line-end-position)))
           (and (re-search-forward "{[[:blank:]]*$" line-end t)
                (save-excursion
                  (goto-char (line-beginning-position))
                  (or (looking-at-p
                       "^[[:blank:]]*proc[[:blank:]]+\\(?:\\(?:::\\)?[[:alnum:]_:]+\\)[[:blank:]]+")
                      (looking-at-p
                       "^[[:blank:]]*namespace[[:blank:]]+eval[[:blank:]]+\\(?:\\(?:::\\)?[[:alnum:]_:]+\\)[[:blank:]]*{"))))))))

(defun mod-tcl--definition-brace-position ()
  "Return the opening brace position for the current definition line, or nil."
  (save-excursion
    (let ((line-end (line-end-position))
          (brace-pos nil))
      (while (re-search-forward "{" line-end t)
        (setq brace-pos (match-beginning 0)))
      brace-pos)))

(defun mod-tcl--definition-bounds ()
  "Return fold bounds for the top-level Tcl definition on the current line.
The result is a cons cell of beginning and end positions, or nil when the
definition cannot be parsed safely."
  (save-excursion
    (let ((start (line-beginning-position)))
      (when-let* ((brace-pos (mod-tcl--definition-brace-position)))
        (goto-char brace-pos)
        (condition-case nil
            (let ((end (scan-sexps (point) 1)))
              (when end
                (goto-char end)
                (end-of-line)
                (when (> (line-number-at-pos (point))
                         (line-number-at-pos start))
                  (cons start (point)))))
          (error nil))))))

(defun mod-tcl--definition-folded-p (beg end)
  "Return non-nil when a hideshow fold already covers BEG..END."
  (cl-some (lambda (ov)
             (and (overlay-get ov 'hs)
                  (<= (overlay-start ov) beg)
                  (>= (overlay-end ov) end)))
           (overlays-in beg end)))

(defun mod-tcl-fold-definitions ()
  "Fold top-level Tcl proc and namespace definitions in the current buffer."
  (interactive)
  (unless (derived-mode-p 'tcl-mode)
    (user-error "Current buffer is not in tcl-mode"))
  (unless (bound-and-true-p hs-minor-mode)
    (hs-minor-mode 1))
  (let ((folds-created 0))
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (if (mod-tcl--definition-start-line-p)
            (let ((next-pos (save-excursion (forward-line 1) (point))))
              (when-let* ((bounds (mod-tcl--definition-bounds))
                          (beg (car bounds))
                          (end (cdr bounds)))
                (unless (mod-tcl--definition-folded-p beg end)
                  (when-let* ((brace-pos (mod-tcl--definition-brace-position)))
                    (goto-char brace-pos)
                    (hs-hide-block)
                    (cl-incf folds-created)))
                (setq next-pos (min (point-max) (1+ end))))
              (goto-char (max next-pos (save-excursion (forward-line 1) (point)))))
          (forward-line 1))))
    (message "Folded %d Tcl definitions" folds-created)))

(defun mod-tcl--maybe-auto-fold-definitions ()
  "Fold top-level Tcl definitions when configured to do so."
  (when orbit-user-tcl-auto-fold-definitions
    (ignore-errors
      (mod-tcl-fold-definitions))))

(defun mod-tcl--doxygen-block-end (start)
  "Return the position after the last line of the Doxygen comment block at START.
START must be the beginning of a line matching '^[[:blank:]]*##'.
Advances past all subsequent lines beginning with optional whitespace
followed by '#' and returns the position of the first non-comment line,
or nil when the line at START is not a Doxygen block start."
  (save-excursion
    (goto-char start)
    (when (looking-at "^[[:blank:]]*##")
      (forward-line 1)
      (while (and (< (point) (point-max))
                  (looking-at "^[[:blank:]]*#"))
        (forward-line 1))
      (point))))

(defun mod-tcl-fold-doxygen-comments ()
  "Fold Doxygen comment blocks in the current Tcl buffer.
A Doxygen block is a run of lines where the first line starts with
optional whitespace followed by '##', and all subsequent lines start
with optional whitespace followed by '#'.  Each such block is folded
with a hideshow overlay.  Blocks that are already folded are skipped."
  (interactive)
  (unless (derived-mode-p 'tcl-mode)
    (user-error "Current buffer is not in tcl-mode"))
  (unless (bound-and-true-p hs-minor-mode)
    (hs-minor-mode 1))
  (let ((folds-created 0))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^[[:blank:]]*##" nil t)
        (let* ((beg (line-beginning-position))
               (end (mod-tcl--doxygen-block-end beg)))
          (when end
            (unless (cl-some (lambda (ov) (overlay-get ov 'hs))
                             (overlays-in beg end))
              (save-excursion
                (goto-char beg)
                (hs-hide-block))
              (cl-incf folds-created)))
          (goto-char (or end (line-end-position))))))
    (message "Folded %d Doxygen comment blocks" folds-created)))

(defun mod-tcl--maybe-auto-fold-doxygen-comments ()
  "Fold Doxygen comment blocks when configured to do so."
  (when orbit-user-tcl-auto-fold-doxygen-comments
    (ignore-errors
      (mod-tcl-fold-doxygen-comments))))

(defconst mod-tcl--local-rename-bare-commands
  '("append" "foreach" "incr" "lappend" "set" "variable")
  "Tcl commands whose bare variable argument can be renamed locally.")

(defun mod-tcl--proc-context ()
  "Return proc context at point, or nil outside a Tcl proc body.
The result is a plist containing `:name', `:body-start', and `:body-end'.
Searches backward so procs indented inside namespace eval blocks are found."
  (save-excursion
    (let ((origin (point)))
      (catch 'found
        (while (re-search-backward
                "^[[:blank:]]*proc[[:blank:]]"
                nil t)
          (when (looking-at
                 "^[[:blank:]]*proc[[:blank:]]+\\(\\(?:::\\)?[[:alnum:]_:]+\\)")
            (let ((name (match-string-no-properties 1)))
              (save-excursion
                (goto-char (match-end 1))
                (skip-chars-forward " \t\n\r")
                (condition-case nil
                    (progn
                      (forward-sexp 1)
                      (skip-chars-forward " \t\n\r")
                      (when (eq (char-after) ?{)
                        (let* ((body-open (point))
                               (body-close (scan-sexps body-open 1)))
                          (when (and body-close
                                     (< body-open origin)
                                     (< origin body-close))
                            (throw 'found
                                   (list :name name
                                         :body-start (1+ body-open)
                                         :body-end (1- body-close)))))))
                  (error nil))))))))))

(defun mod-tcl--symbol-name-at-point ()
  "Return a normalized Tcl variable name at point."
  (let ((line-start (line-beginning-position))
        (line-end (line-end-position))
        (point-pos (point))
        (patterns '("\\${\\([[:alnum:]_:]+\\)}"
                    "\\$\\([[:alnum:]_:]+\\)([^)\n]*)"
                    "\\$\\([[:alnum:]_:]+\\)"
                    "\\_<\\([[:alnum:]_:]+\\)\\_>"))
        symbol)
    (save-excursion
      (dolist (pattern patterns)
        (unless symbol
          (goto-char line-start)
          (while (and (not symbol)
                      (re-search-forward pattern line-end t))
            (when (<= (match-beginning 0) point-pos (match-end 0))
              (setq symbol (match-string-no-properties 1)))))))
    (or symbol
        (when-let* ((thing (thing-at-point 'symbol t)))
          (replace-regexp-in-string "(.*\\'" "" thing))
        (user-error "No Tcl variable at point"))))

(defun mod-tcl--rename-in-text (old-name new-name text)
  "Return a cons (NEW-TEXT . COUNT) with OLD-NAME renamed to NEW-NAME in TEXT.
Operates on the string TEXT directly — no buffer modification during search.
Patterns run in order so earlier passes consume their forms before later ones."
  (let* ((q (regexp-quote old-name))
         (cmds (regexp-opt mod-tcl--local-rename-bare-commands 'words))
         (n 0)
         ;; 1. ${old} → ${new}
         (s (replace-regexp-in-string
             (format "\\${%s}" q)
             (lambda (_) (cl-incf n) (format "${%s}" new-name))
             text t))
         ;; 2. $old(idx) → $new(idx)  — must run before bare $old
         (s (replace-regexp-in-string
             (format "\\$%s(\\([^)\n]*\\))" q)
             (lambda (_)
               (cl-incf n)
               (format "$%s(%s)" new-name (match-string 1)))
             s t))
         ;; 3. $old at symbol boundary → $new
         ;;    Runs after steps 1-2 so ${old} and $old(idx) are already gone.
         (s (replace-regexp-in-string
             (format "\\$%s\\_>" q)
             (lambda (_) (cl-incf n) (format "$%s" new-name))
             s t))
         ;; 4. cmd old → cmd new (bare variable argument: set, variable, incr …)
         ;;    m is exactly "CMD WHITESPACE OLD_NAME" (\_> is zero-width, so
         ;;    nothing trails the match).  Old-name is therefore always the
         ;;    last (length old-name) characters of m — no match-data needed.
         (s (replace-regexp-in-string
             (format "%s[[:blank:]\n]+\\(%s\\)\\_>" cmds q)
             (lambda (m)
               (cl-incf n)
               (concat (substring m 0 (- (length m) (length old-name))) new-name))
             s t)))
    (cons s n)))

(defun mod-tcl--rename-diff-lines (old-text new-text base-line)
  "Return ((LINE-NUM OLD-LINE NEW-LINE) ...) for lines that differ.
BASE-LINE is the 1-based buffer line number of the first line of the text."
  (let* ((old-lines (split-string old-text "\n"))
         (new-lines (split-string new-text "\n"))
         (line base-line)
         changes)
    (cl-mapcar (lambda (old new)
                 (unless (string= old new)
                   (push (list line old new) changes))
                 (cl-incf line))
               old-lines new-lines)
    (nreverse changes)))

(defconst mod-tcl--rename-preview-buffer "*Tcl Rename Preview*"
  "Buffer used to display rename change previews.")

(defun mod-tcl--show-rename-preview (old-name new-name scope matches diff-lines)
  "Render a diff preview for renaming OLD-NAME to NEW-NAME and display it.
SCOPE is a description of the rename region, MATCHES the replacement count,
and DIFF-LINES a list of (LINE-NUM OLD NEW) from `mod-tcl--rename-diff-lines'.
Returns the preview buffer."
  (let ((buf (get-buffer-create mod-tcl--rename-preview-buffer)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize
                 (format "Rename '%s' → '%s'   scope: %s   matches: %d\n\n"
                         old-name new-name scope matches)
                 'face 'bold))
        (let* ((max-line (apply #'max (mapcar #'car diff-lines)))
               (w (length (number-to-string max-line))))
          (dolist (entry diff-lines)
            (pcase-let ((`(,line ,old ,new) entry))
              (insert (propertize
                       (format (format "  %%%dd  - %%s\n" w) line old)
                       'face 'diff-removed))
              (insert (propertize
                       (format (format "  %%%ds  + %%s\n" w) "" new)
                       'face 'diff-added)))))
        (goto-char (point-min)))
      (special-mode))
    (display-buffer
     buf
     `((display-buffer-at-bottom)
       (window-height . ,(min 20 (+ (* 2 (length diff-lines)) 4)))))
    buf))

(defun mod-tcl--program-path (override fallback-name)
  "Return OVERRIDE or a resolved FALLBACK-NAME path, or nil."
  (or override
      (executable-find fallback-name)))

(defun mod-tcl--program-version-output (program)
  "Return PROGRAM --version output trimmed, or nil on failure."
  (when program
    (with-temp-buffer
      (when (eq 0 (ignore-errors
                    (call-process program nil t nil "--version")))
        (string-trim
         (buffer-substring-no-properties (point-min) (point-max)))))))

(defun mod-tcl--docs-root ()
  "Return a practical Tcl docs root, or nil when none can be determined."
  (or (mod-tcl--project-root-for-directory default-directory)
      (when orbit-user-doxygen-config-file
        (file-name-directory orbit-user-doxygen-config-file))
      (when orbit-user-tcl-doxygen-xml-directory
        (file-name-directory
         (directory-file-name
          (file-name-directory
           (directory-file-name orbit-user-tcl-doxygen-xml-directory)))))))

(defun mod-tcl--doxygen-config-path ()
  "Return the configured or default Doxygen config path, or nil."
  (or orbit-user-doxygen-config-file
      (when-let* ((root (mod-tcl--docs-root)))
        (expand-file-name "Doxyfile" root))))

(defun mod-tcl--doxygen-xml-directory-path ()
  "Return the configured or default Doxygen XML directory path, or nil."
  (or orbit-user-tcl-doxygen-xml-directory
      (when-let* ((root (mod-tcl--docs-root)))
        (expand-file-name "docs/xml/" root))))

(defun mod-tcl--diagnostic-line (status label detail)
  "Return a formatted Tcl tooling diagnostic line."
  (format "%-8s %-20s %s" status label (or detail "")))

(defun mod-tcl--ctags-status-line ()
  "Return the Universal Ctags diagnostic line."
  (let* ((program (mod-tcl--program-path orbit-user-ctags-program "ctags"))
         (version (mod-tcl--program-version-output program)))
    (cond
     ((not program)
      (mod-tcl--diagnostic-line "MISSING" "ctags" "Command not found"))
     ((and (eq system-type 'darwin)
           (string= program "/usr/bin/ctags"))
      (mod-tcl--diagnostic-line "WARN" "ctags" (format "%s (likely Apple ctags)" program)))
     ((and version (string-match-p "Apple" version))
      (mod-tcl--diagnostic-line "WARN" "ctags" (format "%s (Apple ctags)" program)))
     ((and version (string-match-p "Universal Ctags" version))
      (mod-tcl--diagnostic-line "OK" "ctags" (format "%s (Universal Ctags)" program)))
     (t
      (mod-tcl--diagnostic-line "OK" "ctags" program)))))

(defun mod-tcl-validate-tooling ()
  "Display a Tcl tooling diagnostic report."
  (interactive)
  (let* ((tclint (mod-tcl--program-path orbit-user-tclint-program "tclint"))
         (tclfmt (mod-tcl--program-path orbit-user-tclfmt-program "tclfmt"))
         (doxygen (mod-tcl--program-path orbit-user-doxygen-program "doxygen"))
         (config-file (mod-tcl--doxygen-config-path))
         (xml-directory (mod-tcl--doxygen-xml-directory-path))
         (index-file (and xml-directory (expand-file-name "index.xml" xml-directory)))
         (known-file (mod-tcl--known-symbols-file-path))
         (known-count (length (mod-tcl--read-known-symbols-file)))
         (lines
          (list
           (mod-tcl--diagnostic-line
            (if tclint "OK" "MISSING") "tclint"
            (or tclint "Command not found"))
           (mod-tcl--diagnostic-line
            (if tclfmt "OK" "MISSING") "tclfmt"
            (or tclfmt "Command not found"))
           (mod-tcl--ctags-status-line)
           (mod-tcl--diagnostic-line
            (if doxygen "OK" "MISSING") "doxygen"
            (or doxygen "Command not found"))
           (mod-tcl--diagnostic-line
            (if (and config-file (file-exists-p config-file)) "OK" "MISSING")
            "Doxyfile"
            (or config-file "No project root or override found"))
           (mod-tcl--diagnostic-line
            (if (and xml-directory (file-directory-p xml-directory)) "OK" "MISSING")
            "docs/xml"
            (or xml-directory "No project root or override found"))
           (mod-tcl--diagnostic-line
            (if (and index-file (file-exists-p index-file)) "OK" "MISSING")
            "index.xml"
            (or index-file "No XML directory found"))
           (mod-tcl--diagnostic-line
            (cond
             ((not known-file) "INFO")
             ((file-exists-p known-file) "OK")
             (t "MISSING"))
            "known symbols"
            (cond
             ((not known-file) "Not configured")
             ((file-exists-p known-file)
              (format "%s (%d symbol%s)"
                      known-file known-count (if (= known-count 1) "" "s")))
             (t known-file))))))
    (mod-tcl--write-output "Tcl Tooling Validation" lines)
    (mod-tcl--display-output-buffer)))

(defun mod-tcl--project-root ()
  "Return the current project root or signal a user-facing error."
  (if-let* ((project (project-current nil)))
      (project-root project)
    (user-error "Not in a project")))

(defun mod-tcl--project-root-for-directory (dir)
  "Return the project root for DIR, or nil if DIR is not in a project."
  (let ((default-directory dir))
    (when-let* ((project (project-current nil)))
      (project-root project))))

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

(defun mod-tcl--project-tags-file-for-root (root)
  "Return the TAGS file path for ROOT."
  (expand-file-name "TAGS" root))

(defun mod-tcl--visit-project-tags-table ()
  "Visit the current project's TAGS file and return its path."
  (let ((tags-file (mod-tcl--project-tags-file)))
    (unless (file-exists-p tags-file)
      (user-error "No TAGS file found at %s" tags-file))
    (visit-tags-table tags-file t)
    tags-file))

(defun mod-tcl--normalize-tag-symbol (symbol)
  "Return a practical Tcl symbol spelling for SYMBOL."
  (if (string-prefix-p "::" symbol)
      (string-remove-prefix "::" symbol)
    symbol))

(defun mod-tcl--parse-tags-namespace (line)
  "Return a normalized namespace from TAGS LINE, or nil.
Only simple `namespace eval NAME' entries are recognized."
  (when (string-match
         "^[ \t]*namespace[ \t]+eval[ \t]+\\(\\(?:::\\)?[A-Za-z0-9_:]+\\)\\(?:[ \t]+{\\|[ \t]*$\\)"
         line)
    (mod-tcl--normalize-tag-symbol (match-string 1 line))))

(defun mod-tcl--parse-tags-proc-line (line)
  "Return Tcl proc metadata parsed from TAGS LINE, or nil.
The result is a plist containing `:symbol' and `:indented'."
  (when (string-match
         "^\\([ \t]*\\)proc[ \t]+\\(\\(?:::\\)?[A-Za-z0-9_:]+\\)[ \t]*{"
         line)
    (list :symbol (mod-tcl--normalize-tag-symbol (match-string 2 line))
          :indented (> (length (match-string 1 line)) 0))))

(defun mod-tcl--parse-tags-section-symbols (start end qualified unqualified-counts)
  "Parse Tcl symbols in the TAGS section between START and END.
Fully qualified proc names are recorded in QUALIFIED. Unique bare proc names
are counted in UNQUALIFIED-COUNTS. Namespace synthesis is reset for each
section so file-local context does not leak across TAGS entries."
  (let ((namespace nil))
    (save-excursion
      (goto-char start)
      (while (< (point) end)
        (let* ((line-end (min end (line-end-position)))
               (line (buffer-substring-no-properties (point) line-end)))
          (when-let* ((parsed-namespace (mod-tcl--parse-tags-namespace line)))
            (setq namespace parsed-namespace))
          (when-let* ((proc (mod-tcl--parse-tags-proc-line line))
                      (symbol (plist-get proc :symbol)))
            (if (mod-tcl--symbol-qualified-p symbol)
                (push symbol qualified)
              (puthash symbol (1+ (gethash symbol unqualified-counts 0))
                       unqualified-counts)
              ;; Only synthesize namespace-qualified names for indented proc
              ;; tags after a matching namespace entry in the same TAGS section.
              (when (and namespace (plist-get proc :indented))
                (push (concat namespace "::" symbol) qualified))))
          (forward-line 1))))
    qualified))

(defun mod-tcl--parse-tags-symbols (tags-file)
  "Return conservative Tcl proc symbols parsed from TAGS-FILE.
Fully qualified proc names are preferred. Unqualified names are included only
when they are unique across the current TAGS file. When a TAGS section records
`namespace eval NAME' followed by indented unqualified proc tags, synthesized
`NAME::proc' symbols are added conservatively for that section."
  (let ((qualified '())
        (unqualified-counts (make-hash-table :test #'equal))
        (unique-unqualified '()))
    (with-temp-buffer
      (insert-file-contents tags-file)
      (goto-char (point-min))
      (let ((section-start (point-min)))
        (while (< section-start (point-max))
          (let ((section-end (or (save-excursion
                                   (goto-char section-start)
                                   (when (search-forward "\f" nil t)
                                     (1- (point))))
                                 (point-max))))
            (setq qualified
                  (mod-tcl--parse-tags-section-symbols
                   section-start section-end qualified unqualified-counts))
            (setq section-start
                  (if (< section-end (point-max))
                      (1+ section-end)
                    (point-max)))))))
    (maphash
     (lambda (symbol count)
       (when (= count 1)
         (push symbol unique-unqualified)))
     unqualified-counts)
    (delete-dups (nreverse (append qualified unique-unqualified)))))

(defun mod-tcl--read-known-symbols-file (&optional message-missing)
  "Return symbols from `orbit-user-tcl-known-symbols-file'.
When MESSAGE-MISSING is non-nil, emit a clear message if the configured file
does not exist. Blank lines and lines starting with `#' are ignored."
  (let ((file (mod-tcl--known-symbols-file-path))
        (symbols '()))
    (cond
     ((not file) nil)
     ((not (file-exists-p file))
      (when message-missing
        (message "Tcl known symbols file not found: %s" file))
      nil)
     (t
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (string-trim
                       (buffer-substring-no-properties
                        (line-beginning-position)
                        (line-end-position)))))
            (unless (or (string-empty-p line)
                        (string-prefix-p "#" line))
              (let ((symbol (mod-tcl--normalize-tag-symbol line)))
                (when (string-match-p "\\`[A-Za-z0-9_:]+\\'" symbol)
                  (push symbol symbols)))))
          (forward-line 1)))
      (delete-dups (nreverse symbols))))))

(defun mod-tcl--known-symbols-file-path ()
  "Return the configured known-symbols file path, normalized when possible."
  (when orbit-user-tcl-known-symbols-file
    (expand-file-name orbit-user-tcl-known-symbols-file)))

(defun mod-tcl--collect-highlight-symbols (&optional message-missing)
  "Return Tcl symbols to highlight for the current buffer.
Project TAGS symbols remain the foundation. Symbols from
`orbit-user-tcl-known-symbols-file' are merged in when available. When
MESSAGE-MISSING is non-nil, report a missing configured known symbols file."
  (let* ((root (mod-tcl--project-root-for-directory default-directory))
         (tags-file (and root (mod-tcl--project-tags-file-for-root root)))
         (tags-symbols (when (and tags-file (file-exists-p tags-file))
                         (mod-tcl--parse-tags-symbols tags-file)))
         (user-symbols (mod-tcl--read-known-symbols-file message-missing)))
    (delete-dups (append tags-symbols user-symbols))))

(defun mod-tcl--symbol-qualified-p (symbol)
  "Return non-nil when SYMBOL is namespace-qualified."
  (string-match-p "::" symbol))

(defun mod-tcl--sort-symbols (symbols)
  "Return SYMBOLS sorted with qualified names first."
  (sort (delete-dups (copy-sequence symbols))
        (lambda (left right)
          (let ((left-qualified (mod-tcl--symbol-qualified-p left))
                (right-qualified (mod-tcl--symbol-qualified-p right)))
            (cond
             ((and left-qualified (not right-qualified)) t)
             ((and right-qualified (not left-qualified)) nil)
             (t (string-lessp left right)))))))

(defun mod-tcl--canonical-search-symbols (symbols)
  "Return canonical search candidates derived from SYMBOLS.
Fully qualified names are preferred. A bare name is removed from the search
list when a qualified `ns::name' candidate already exists, but top-level bare
names are preserved when no qualified form is present."
  (let ((qualified-by-tail (make-hash-table :test #'equal))
        (candidates '()))
    (dolist (symbol symbols)
      (when (mod-tcl--symbol-qualified-p symbol)
        (puthash (car (last (split-string symbol "::" t))) t qualified-by-tail)))
    (dolist (symbol symbols)
      (when (or (mod-tcl--symbol-qualified-p symbol)
                (not (gethash symbol qualified-by-tail)))
        (push symbol candidates)))
    (mod-tcl--sort-symbols candidates)))

(defun mod-tcl--file-mtime (file)
  "Return FILE's modification time, or nil when FILE is missing."
  (when (and file (file-exists-p file))
    (file-attribute-modification-time (file-attributes file))))

(defun mod-tcl--canonical-symbol-cache-key (root tags-file known-file)
  "Return a cache key for ROOT, TAGS-FILE, and KNOWN-FILE."
  (list root
        tags-file
        (mod-tcl--file-mtime tags-file)
        known-file
        (mod-tcl--file-mtime known-file)))

(defun mod-tcl--canonical-symbols (&optional message-missing require-tags)
  "Return canonical Tcl symbols for the current context.
When MESSAGE-MISSING is non-nil, report a missing configured known-symbols
file. When REQUIRE-TAGS is non-nil, return nil unless the current project has
an existing TAGS file."
  (let* ((root (mod-tcl--project-root-for-directory default-directory))
         (tags-file (and root (mod-tcl--project-tags-file-for-root root)))
         (known-file (mod-tcl--known-symbols-file-path)))
    (when (or (not require-tags)
              (and tags-file (file-exists-p tags-file))
              known-file)
      (let ((cache-key (mod-tcl--canonical-symbol-cache-key root tags-file known-file)))
        (or (gethash cache-key mod-tcl--canonical-symbol-cache)
            (let ((symbols
                   (mod-tcl--canonical-search-symbols
                    (mod-tcl--collect-highlight-symbols message-missing))))
              (puthash cache-key symbols mod-tcl--canonical-symbol-cache)
              symbols))))))

(defun mod-tcl--invalidate-canonical-symbol-cache (&optional root)
  "Clear cached canonical Tcl symbols.
When ROOT is non-nil, only remove cache entries for that project root."
  (if root
      (maphash
       (lambda (key _value)
         (when (equal (car key) root)
           (remhash key mod-tcl--canonical-symbol-cache)))
       mod-tcl--canonical-symbol-cache)
    (clrhash mod-tcl--canonical-symbol-cache)))

(defun mod-tcl--completion-bounds ()
  "Return practical Tcl symbol completion bounds at point."
  (save-excursion
    (let ((end (point)))
      (skip-chars-backward "A-Za-z0-9_:")
      (let ((beg (point)))
        (when (< beg end)
          (cons beg end))))))

(defun mod-tcl--completion-placeholder-names (candidate)
  "Return snippet placeholder names for Tcl completion CANDIDATE."
  (when (fboundp 'mod-tcl-docs-completion-entry)
    (when-let* ((doc (ignore-errors (mod-tcl-docs-completion-entry candidate)))
                (kind (plist-get doc :kind))
                ((equal kind "function")))
      (let* ((argsstring (plist-get doc :argsstring))
             (parameters (plist-get doc :parameters))
             (names (or (mod-tcl--completion-argsstring-names argsstring)
                        (and parameters (mapcar #'car parameters)))))
        (setq names
              (cl-remove-duplicates
               (delq nil
                     (mapcar
                      (lambda (name)
                        (when (and (stringp name)
                                   (string-match-p "\\`[[:alpha:]_][[:alnum:]_]*\\'" name))
                          name))
                      names))
               :test #'equal))
        (unless (null names)
          names)))))

(defun mod-tcl--completion-argsstring-names (argsstring)
  "Return ordered Tcl argument names parsed from ARGSSTRING."
  (when (and (stringp argsstring) (not (string-empty-p argsstring)))
    (let* ((text (string-trim argsstring))
           (inner (if (and (> (length text) 1)
                           (eq (aref text 0) ?{)
                           (eq (aref text (1- (length text))) ?}))
                      (substring text 1 -1)
                    text))
           (token "")
           (depth 0)
           tokens)
      (cl-labels ((flush-token ()
                    (let ((trimmed (string-trim token)))
                      (unless (string-empty-p trimmed)
                        (push trimmed tokens)))
                    (setq token "")))
        (mapc
         (lambda (char)
           (cond
            ((and (= depth 0) (memq char '(?\s ?\t ?\n ?\r)))
             (flush-token))
            (t
             (setq token (concat token (string char)))
             (cond
              ((eq char ?{) (setq depth (1+ depth)))
              ((and (eq char ?}) (> depth 0)) (setq depth (1- depth)))))))
         (string-to-list inner))
        (flush-token))
      (let (names)
        (dolist (item (nreverse tokens))
          (let* ((trimmed (string-trim item "{} \t\n\r"))
                 (name (car (split-string trimmed "[ \t\n\r]+" t))))
            (when (and name
                       (string-match-p "\\`[[:alpha:]_][[:alnum:]_]*\\'" name))
              (push name names))))
        (nreverse names)))))

(defun mod-tcl--completion-snippet-body (candidate)
  "Return a Yasnippet body for Tcl completion CANDIDATE, or nil."
  (when-let* ((names (mod-tcl--completion-placeholder-names candidate)))
    (concat
     candidate
     " "
     (mapconcat
      (lambda (entry)
        (pcase-let ((`(,index . ,name) entry))
          (format "${%d:%s}" index name)))
      (cl-mapcar #'cons
                 (number-sequence 1 (length names))
                 names)
      " ")
     "$0")))

(defun mod-tcl--completion-exit (candidate status)
  "Expand Tcl completion placeholders for CANDIDATE when STATUS is `finished'."
  (when (and (eq status 'finished)
             (bound-and-true-p yas-minor-mode)
             (fboundp 'yas-expand-snippet))
    (when-let* ((snippet (mod-tcl--completion-snippet-body candidate)))
      (let ((end (point))
            (beg (- (point) (length candidate))))
        (when (>= beg (point-min))
          (yas-expand-snippet snippet beg end))))))

(defun mod-tcl-completion-at-point ()
  "Provide Tcl symbol completion from project TAGS and known symbols."
  (when (and (derived-mode-p 'tcl-mode)
             (not (active-minibuffer-window)))
    (when-let* ((bounds (mod-tcl--completion-bounds))
                (symbols (mod-tcl--canonical-symbols nil)))
      (pcase-let ((`(,beg . ,end) bounds))
        (list beg end
              (completion-table-dynamic
               (lambda (_string)
                 (mod-tcl--canonical-symbols nil)))
              :exclusive 'no
              :annotation-function
              (lambda (candidate)
                (when (fboundp 'mod-tcl-docs-completion-summary)
                  (ignore-errors
                    (mod-tcl-docs-completion-summary candidate))))
              :category 'tcl-symbol
              :company-doc-buffer
              (lambda (candidate)
                (when (fboundp 'mod-tcl-docs-completion-doc-buffer)
                  (ignore-errors
                    (mod-tcl-docs-completion-doc-buffer candidate))))
              :company-location
              (lambda (candidate)
                (when (fboundp 'mod-tcl-docs-completion-location)
                  (ignore-errors
                    (mod-tcl-docs-completion-location candidate))))
              :exit-function #'mod-tcl--completion-exit)))))

(defun mod-tcl-setup-completion ()
  "Add Tcl symbol completion to the current buffer's CAPF flow."
  (add-hook 'completion-at-point-functions #'mod-tcl-completion-at-point nil t)
  (when (and (bound-and-true-p yas-minor-mode)
             (fboundp 'mod-snippets-setup-completion))
    (mod-snippets-setup-completion)))

(defun mod-tcl--symbol-highlight-matcher (limit)
  "Search for a known Tcl project symbol before LIMIT.
Matches inside comments and strings are ignored."
  (catch 'match
    (while (and mod-tcl--symbol-highlight-regexp
                (re-search-forward mod-tcl--symbol-highlight-regexp limit t))
      (unless (nth 8 (syntax-ppss (match-beginning 1)))
        (throw 'match t)))))

(defun mod-tcl--build-symbol-highlight-regexp (symbols)
  "Return a regexp that matches SYMBOLS conservatively."
  (when symbols
    (concat
     "\\(?:^\\|[^[:alnum:]_:]\\)"
     "\\("
     (regexp-opt symbols)
     "\\)"
     "\\(?:$\\|[^[:alnum:]_:]\\)")))

(defun mod-tcl--apply-symbol-highlighting (symbols)
  "Apply Tcl project symbol highlighting for SYMBOLS in the current buffer."
  (font-lock-remove-keywords nil mod-tcl--symbol-highlight-keywords)
  (setq mod-tcl--symbol-highlight-regexp
        (mod-tcl--build-symbol-highlight-regexp symbols))
  (when mod-tcl--symbol-highlight-regexp
    (font-lock-add-keywords nil mod-tcl--symbol-highlight-keywords 'append))
  (when font-lock-mode
    (font-lock-flush)
    (font-lock-ensure)))

(defun mod-tcl-refresh-symbol-highlighting ()
  "Refresh Tcl symbol highlighting from TAGS and user-known symbols."
  (interactive)
  (unless (derived-mode-p 'tcl-mode)
    (user-error "Current buffer is not in tcl-mode"))
  (mod-tcl--apply-symbol-highlighting
   (mod-tcl--sort-symbols
    (mod-tcl--collect-highlight-symbols
     (called-interactively-p 'interactive)))))

(defun mod-tcl--find-project-symbol (symbol)
  "Jump to SYMBOL using the current project's TAGS file.
Return non-nil when a project definition was found."
  (let ((root (mod-tcl--project-root-for-directory default-directory)))
    (when root
      (let ((tags-file (mod-tcl--project-tags-file-for-root root)))
        (when (file-exists-p tags-file)
          (visit-tags-table tags-file t)
          (mod-tcl--find-tag-with-fallbacks symbol))))))

(defun mod-tcl-search-symbols ()
  "Search known Tcl symbols and jump to a project definition when available."
  (interactive)
  (unless (derived-mode-p 'tcl-mode)
    (user-error "Current buffer is not in tcl-mode"))
  (let* ((symbols (mod-tcl--canonical-symbols
                   (called-interactively-p 'interactive)))
         (default-symbol (thing-at-point 'symbol t)))
    (unless symbols
      (user-error "No Tcl symbols available"))
    (let ((symbol (completing-read "Tcl symbol: " symbols nil t nil nil default-symbol)))
      (unless (mod-tcl--find-project-symbol symbol)
        (message "Known external symbol has no project definition: %s" symbol)))))

(defun mod-tcl--refresh-symbol-highlighting-in-project (root)
  "Refresh Tcl symbol highlighting in all live Tcl buffers for ROOT."
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (and (derived-mode-p 'tcl-mode)
                 buffer-file-name
                 (equal (mod-tcl--project-root-for-directory default-directory) root))
        (mod-tcl-refresh-symbol-highlighting)))))

(defun mod-tcl--enable-symbol-highlighting ()
  "Enable Tcl project symbol highlighting for the current buffer when possible."
  (when (and (derived-mode-p 'tcl-mode)
             buffer-file-name)
    (ignore-errors
      (mod-tcl-refresh-symbol-highlighting))))

(defun mod-tcl--symbol-at-point ()
  "Return the Tcl symbol at point or signal a user-facing error."
  (or (thing-at-point 'symbol t)
      (user-error "No symbol at point")))

(defun mod-tcl-rename-local-symbol (new-name &optional old-name)
  "Rename OLD-NAME to NEW-NAME in the surrounding proc body, or the entire buffer.
When point is inside a Tcl proc the rename is limited to that proc body.
When no enclosing proc is found the rename covers the entire buffer.
A diff preview is shown before the user confirms."
  (interactive
   (let* ((old-name (mod-tcl--symbol-name-at-point))
          (new-name (read-string
                     (format "Rename Tcl variable %s to: " old-name)
                     nil nil old-name)))
     (list new-name old-name)))
  (unless (derived-mode-p 'tcl-mode)
    (user-error "Current buffer is not in tcl-mode"))
  (let* ((old-name (or old-name (mod-tcl--symbol-name-at-point)))
         (context (or (mod-tcl--proc-context)
                      (list :name nil
                            :body-start (point-min)
                            :body-end (point-max))))
         (scope (if (plist-get context :name)
                    (format "proc %s" (plist-get context :name))
                  "entire buffer")))
    (when (or (string-empty-p new-name)
              (string= new-name old-name))
      (user-error "New Tcl variable name must differ from %s" old-name))
    (unless (string-match-p "\\`[[:alpha:]_][[:alnum:]_:]*\\'" new-name)
      (user-error "Not a valid Tcl variable name: %s" new-name))
    (let* ((beg (plist-get context :body-start))
           (end (plist-get context :body-end))
           (original (buffer-substring-no-properties beg end))
           (result (mod-tcl--rename-in-text old-name new-name original))
           (new-text (car result))
           (matches (cdr result)))
      (if (= matches 0)
          (message "No Tcl variable matches for '%s' in %s" old-name scope)
        (let* ((base-line (line-number-at-pos beg))
               (diff-lines (mod-tcl--rename-diff-lines original new-text base-line))
               (preview-buf (mod-tcl--show-rename-preview
                             old-name new-name scope matches diff-lines)))
          (unwind-protect
              (when (yes-or-no-p
                     (format "Apply %d rename(s) of '%s' → '%s'? "
                             matches old-name new-name))
                (barf-if-buffer-read-only)
                ;; Apply line-by-line (bottom-to-top) so overlays on
                ;; unchanged lines — including any hideshow folds — survive.
                (atomic-change-group
                  (let ((inhibit-read-only t))
                    (dolist (entry (reverse diff-lines))
                      (pcase-let ((`(,line ,_old ,new) entry))
                        (save-excursion
                          (goto-char (point-min))
                          (forward-line (1- line))
                          (delete-region (point) (line-end-position))
                          (insert new))))))
                (message "Renamed %d occurrence(s) of '%s' in %s"
                         matches old-name scope))
            (when (buffer-live-p preview-buf)
              (delete-windows-on preview-buf)
              (kill-buffer preview-buf))))))))

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
    (let ((buffer (mod-tcl--run-compilation program mod-tcl-ctags-args root)))
      (with-current-buffer buffer
        (add-hook
         'compilation-finish-functions
         (lambda (_buffer status)
           (when (string-match-p "\\`finished" status)
             (mod-tcl--invalidate-canonical-symbol-cache root)
             (mod-tcl--refresh-symbol-highlighting-in-project root)))
         nil t)))
    (when-let* ((tags-file (expand-file-name "TAGS" root)))
      (when (file-exists-p tags-file)
        (visit-tags-table tags-file t)))))

(defalias 'mod-tcl-show-output #'mod-tcl--display-output-buffer)

(with-eval-after-load 'tcl
  ;; Tell hideshow how to find Tcl blocks (brace-delimited, # comments).
  (add-to-list 'hs-special-modes-alist
               '(tcl-mode "{" "}" "#" nil nil))
  (add-hook 'tcl-mode-hook #'mod-tcl--configure-editing-defaults)
  (add-hook 'tcl-mode-hook #'mod-tcl-enable-manual-folding)
  (add-hook 'tcl-mode-hook #'mod-tcl--maybe-auto-fold-definitions)
  (add-hook 'tcl-mode-hook #'mod-tcl--maybe-auto-fold-doxygen-comments)
  (add-hook 'tcl-mode-hook #'mod-tcl-setup-completion)
  (add-hook 'tcl-mode-hook #'mod-tcl--enable-symbol-highlighting))

(provide 'mod-tcl)

;;; mod-tcl.el ends here
