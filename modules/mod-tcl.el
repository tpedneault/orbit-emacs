;;; mod-tcl.el --- Minimal Tcl workflow foundation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'compile)
(require 'etags)
(require 'project)
(require 'subr-x)
(require 'xref)

(declare-function mod-tcl-docs-doxygen-config-file "mod-tcl-docs")
(declare-function mod-snippets-setup-completion "mod-snippets")
(declare-function evil-vimish-fold-mode "evil-vimish-fold")
(declare-function vimish-fold "vimish-fold")
(declare-function vimish-fold-mode "vimish-fold")
(declare-function vimish-fold-toggle "vimish-fold")

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
  "Enable stable manual folding for Tcl buffers."
  (when (fboundp 'vimish-fold-mode)
    (vimish-fold-mode 1))
  (when (fboundp 'evil-vimish-fold-mode)
    (evil-vimish-fold-mode 1)))

(defun mod-tcl-toggle-fold ()
  "Toggle a manual fold at point."
  (interactive)
  (condition-case nil
      (vimish-fold-toggle)
    (error
     (message "No manual fold at point"))))

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
  "Return non-nil when a vimish fold already covers BEG..END."
  (cl-some
   (lambda (overlay)
     (and (memq (overlay-get overlay 'type)
                '(vimish-fold--folded vimish-fold--unfolded))
          (<= (overlay-start overlay) beg)
          (>= (overlay-end overlay) end)))
   (overlays-in beg end)))

(defun mod-tcl-fold-definitions ()
  "Fold top-level Tcl proc and namespace definitions in the current buffer."
  (interactive)
  (unless (derived-mode-p 'tcl-mode)
    (user-error "Current buffer is not in tcl-mode"))
  (unless (fboundp 'vimish-fold)
    (user-error "vimish-fold is not available"))
  (unless (bound-and-true-p vimish-fold-mode)
    (vimish-fold-mode 1))
  (let ((folds-created 0))
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (let ((line-start (line-beginning-position)))
          (cond
           ((mod-tcl--definition-start-line-p)
            (let ((next-pos (save-excursion (forward-line 1) (point))))
              (when-let* ((bounds (mod-tcl--definition-bounds)))
                (pcase-let ((`(,beg . ,end) bounds))
                  (unless (mod-tcl--definition-folded-p beg end)
                    (vimish-fold beg end)
                    (setq folds-created (1+ folds-created)))
                  (setq next-pos (min (point-max) (1+ end)))))
              (goto-char (max next-pos (save-excursion (forward-line 1) (point))))))
           (t
            (forward-line 1))))))
    (message "Folded %d Tcl definitions" folds-created)))

(defun mod-tcl--maybe-auto-fold-definitions ()
  "Fold top-level Tcl definitions when configured to do so."
  (when orbit-user-tcl-auto-fold-definitions
    (ignore-errors
      (mod-tcl-fold-definitions))))

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
            (or index-file "No XML directory found")))))
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
  (let ((file orbit-user-tcl-known-symbols-file)
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
         (known-file orbit-user-tcl-known-symbols-file))
    (when (or (not require-tags)
              (and tags-file (file-exists-p tags-file)))
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

(defun mod-tcl-completion-at-point ()
  "Provide Tcl symbol completion from project TAGS and known symbols."
  (when (and (derived-mode-p 'tcl-mode)
             (not (active-minibuffer-window)))
    (when-let* ((bounds (mod-tcl--completion-bounds))
                (symbols (mod-tcl--canonical-symbols nil t)))
      (pcase-let ((`(,beg . ,end) bounds))
        (list beg end
              (completion-table-dynamic
               (lambda (_string)
                 (mod-tcl--canonical-symbols nil t)))
              :exclusive 'no)))))

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
  (add-hook 'tcl-mode-hook #'mod-tcl--configure-editing-defaults)
  (add-hook 'tcl-mode-hook #'mod-tcl-enable-manual-folding)
  (add-hook 'tcl-mode-hook #'mod-tcl--maybe-auto-fold-definitions)
  (add-hook 'tcl-mode-hook #'mod-tcl-setup-completion)
  (add-hook 'tcl-mode-hook #'mod-tcl--enable-symbol-highlighting))

(provide 'mod-tcl)

;;; mod-tcl.el ends here
