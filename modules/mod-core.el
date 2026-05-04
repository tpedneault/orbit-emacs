;;; mod-core.el --- Core bootstrap -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'browse-url)
(require 'project)
(require 'thingatpt)

(declare-function mod-context-open-path "mod-context")

(defconst mod-core-config-directory
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name)))))
(defconst mod-core-var-directory
  (expand-file-name "var/" mod-core-config-directory))
(defconst mod-core-backup-directory
  (expand-file-name "backups/" mod-core-var-directory))
(defconst mod-core-auto-save-directory
  (expand-file-name "auto-save/" mod-core-var-directory))
(defconst mod-core-lockfile-directory
  (expand-file-name "lockfiles/" mod-core-var-directory))
(defconst mod-core-lockfile-transforms
  `(( "\\`.+\\'"
      ,(file-name-as-directory mod-core-lockfile-directory)
      sha256))
  "Redirect lockfiles into `mod-core-lockfile-directory'.

The `sha256' uniquifier makes the lockfile name depend on the full source
file path rather than only its basename, which avoids simple collisions
between same-named files in different directories.")
(defconst mod-core-savehist-file
  (expand-file-name "history" mod-core-var-directory))
(defconst mod-core-save-place-file
  (expand-file-name "places" mod-core-var-directory))
(defconst mod-core-user-directory
  (expand-file-name
   ".orbit-emacs.d/"
   (file-name-directory
    (directory-file-name mod-core-config-directory))))
(defconst mod-core-user-config-file
  (expand-file-name "config.el" mod-core-user-directory))
(defconst mod-core-user-snippets-directory
  (expand-file-name "snippets/" mod-core-user-directory))
(defconst mod-core-user-config-template
  ";;; config.el --- User overrides for orbit-emacs -*- lexical-binding: t; -*-\n\
;; Uncomment and adjust any setting to override the orbit-emacs default.\n\n\
;; ─── General ─────────────────────────────────────────────────────────────────\n\n\
;; Shell used for `shell-file-name' and `explicit-shell-file-name'.\n\
;; (setq orbit-user-shell \"/bin/zsh\")\n\n\
;; Default org directory (used by mod-org for agenda, capture, etc.).\n\
;; (setq orbit-user-org-directory (expand-file-name \"org/\" (getenv \"HOME\")))\n\n\
;; Directory containing your personal YASnippet snippets.\n\
;; (setq orbit-user-snippets-directory\n\
;;       (expand-file-name \"snippets/\" (expand-file-name \".orbit-emacs.d/\" (getenv \"HOME\"))))\n\n\
;; ─── Fonts ───────────────────────────────────────────────────────────────────\n\n\
;; Monospace font used for the default and fixed-pitch faces.\n\
;; (setq orbit-user-font-family \"IBM Plex Mono\")\n\n\
;; Font height in units of 1/10 pt.  140 = 14 pt.\n\
;; (setq orbit-user-font-height 140)\n\n\
;; Font weight for the default and fixed-pitch faces.\n\
;; Common values: light, regular, medium, semibold, bold, extrabold.\n\
;; (setq orbit-user-font-weight 'regular)\n\n\
;; Proportional font used for variable-pitch face (org prose, etc.).\n\
;; Leave nil to keep everything monospace.\n\
;; (setq orbit-user-variable-pitch-font \"Inter\")\n\n\
;; Height for the variable-pitch face.  Use a float (e.g. 1.0) to stay\n\
;; relative to the default height, or an integer (e.g. 150) for absolute.\n\
;; (setq orbit-user-variable-pitch-height 1.0)\n\n\
;; Weight for the variable-pitch face.\n\
;; (setq orbit-user-variable-pitch-weight 'regular)\n\n\
;; ─── Editor defaults ─────────────────────────────────────────────────────────\n\n\
;; Show a vertical line at this column in all buffers.\n\
;; (setq orbit-user-enable-fill-column-indicator t)\n\
;; (setq orbit-user-fill-column 120)\n\n\
;; Highlight trailing whitespace and tabs in all buffers.\n\
;; (setq orbit-user-enable-whitespace t)\n\n\
;; Highlight the current line in all buffers.\n\
;; (setq orbit-user-enable-hl-line t)\n\n\
;; ─── Tools ───────────────────────────────────────────────────────────────────\n\n\
;; Ripgrep binary used for project-wide search.\n\
;; (setq orbit-user-rg-program \"rg\")\n\n\
;; Universal Ctags binary used for tag generation.\n\
;; (setq orbit-user-ctags-program \"ctags\")\n\n\
;; ─── TCL ─────────────────────────────────────────────────────────────────────\n\n\
;; External TCL linter and formatter binaries.\n\
;; (setq orbit-user-tclint-program \"tclint\")\n\
;; (setq orbit-user-tclfmt-program \"tclfmt\")\n\n\
;; Indentation width for TCL source files.\n\
;; (setq orbit-user-tcl-indent-width 3)\n\n\
;; Fill column for TCL source files.\n\
;; (setq orbit-user-tcl-fill-column 120)\n\n\
;; Use hard tabs instead of spaces in TCL files.\n\
;; (setq orbit-user-tcl-use-tabs nil)\n\n\
;; Per-language overrides — set to t, nil, or 'inherit to follow the global.\n\
;; (setq orbit-user-tcl-enable-fill-column-indicator 'inherit)\n\
;; (setq orbit-user-tcl-enable-whitespace 'inherit)\n\
;; (setq orbit-user-tcl-enable-hl-line 'inherit)\n\n\
;; Auto-fold proc/namespace definitions on file open.\n\
;; (setq orbit-user-tcl-auto-fold-definitions nil)\n\n\
;; Path to a plain-text file of known TCL symbols (one per line).\n\
;; (setq orbit-user-tcl-known-symbols-file \"/path/to/tcl-known-symbols.txt\")\n\n\
;; Directory containing Doxygen XML output for TCL API docs.\n\
;; (setq orbit-user-tcl-doxygen-xml-directory nil)\n\n\
;; Doxygen binary and config file used by mod-tcl-docs.\n\
;; (setq orbit-user-doxygen-program \"doxygen\")\n\
;; (setq orbit-user-doxygen-config-file nil)\n\n\
;; ─── Jira ────────────────────────────────────────────────────────────────────\n\n\
;; Base URL for your Jira instance.\n\
;; (setq orbit-user-jira-base-url \"https://jira.example.com\")\n\n\
;; REST API prefix (v2 default; change to \"/rest/api/3\" for Jira Cloud).\n\
;; (setq orbit-user-jira-api-prefix \"/rest/api/2\")\n\n\
;; Jira project key used as the default for queries.\n\
;; (setq orbit-user-jira-project-key \"PROJ\")\n\n\
;; Your Jira login username (usually email on Cloud).\n\
;; (setq orbit-user-jira-username \"thomas\")\n\n\
;; JQL query string used for the default issue list (nil = use project key).\n\
;; (setq orbit-user-jira-jql nil)\n\n\
;; Org file where synced Jira issues are stored.\n\
;; (setq orbit-user-jira-org-file\n\
;;       (expand-file-name \"jira.org\" (expand-file-name \"org/\" (getenv \"HOME\"))))\n\n\
;; Shell command that prints your Jira Personal Access Token on stdout.\n\
;; (setq orbit-user-jira-token-command\n\
;;       \"security find-generic-password -a jira -s orbit-jira-pat -w\")\n\n\
;; Environment variable to read the PAT from (alternative to token-command).\n\
;; (setq orbit-user-jira-pat-env \"JIRA_PAT\")\n")

(defvar orbit-user-shell nil)
(defvar orbit-user-font-family nil)
(defvar orbit-user-font-height nil)
(defvar orbit-user-font-weight nil)
(defvar orbit-user-variable-pitch-font nil)
(defvar orbit-user-variable-pitch-height nil)
(defvar orbit-user-variable-pitch-weight nil)
(defvar orbit-user-org-directory nil)
(defvar orbit-user-snippets-directory nil)
(defvar orbit-user-rg-program nil)
(defvar orbit-user-ctags-program nil)
(defvar orbit-user-tclint-program nil)
(defvar orbit-user-tclfmt-program nil)
(defvar orbit-user-enable-fill-column-indicator t)
(defvar orbit-user-fill-column 120)
(defvar orbit-user-tcl-indent-width 3)
(defvar orbit-user-tcl-fill-column 120)
(defvar orbit-user-tcl-use-tabs nil)
(defvar orbit-user-enable-whitespace t)
(defvar orbit-user-enable-hl-line t)
(defvar orbit-user-tcl-enable-fill-column-indicator 'inherit)
(defvar orbit-user-tcl-enable-whitespace 'inherit)
(defvar orbit-user-tcl-enable-hl-line 'inherit)
(defvar orbit-user-tcl-auto-fold-definitions nil)
(defvar orbit-user-tcl-known-symbols-file nil)
(defvar orbit-user-tcl-doxygen-xml-directory nil)
(defvar orbit-user-doxygen-program nil)
(defvar orbit-user-doxygen-config-file nil)
(defvar orbit-user-jira-base-url nil)
(defvar orbit-user-jira-api-prefix "/rest/api/2")
(defvar orbit-user-jira-project-key nil)
(defvar orbit-user-jira-username nil)
(defvar orbit-user-jira-jql nil)
(defvar orbit-user-jira-org-file nil)
(defvar orbit-user-jira-token-command nil)
(defvar orbit-user-jira-pat-env nil)

(defvar mod-core-recentf-history nil
  "Minibuffer history for recent file selection.")

(defun mod-core-gui-shell-environment-p ()
  "Return non-nil when shell environment import should run."
  (and (memq system-type '(darwin gnu/linux))
       (or (display-graphic-p)
           (daemonp))))

(defun mod-core-ensure-user-files ()
  "Ensure the user-local orbit-emacs files exist."
  (make-directory mod-core-user-directory t)
  (make-directory mod-core-user-snippets-directory t)
  (unless (file-exists-p mod-core-user-config-file)
    (write-region mod-core-user-config-template nil mod-core-user-config-file nil 'silent)))

(defun mod-core--require-elpaca (repo)
  (let ((load-path (cons repo load-path)))
    (require 'elpaca)))

(dolist (dir (list mod-core-var-directory
                   mod-core-backup-directory
                   mod-core-auto-save-directory
                   mod-core-lockfile-directory))
  (make-directory dir t))

(mod-core-ensure-user-files)
(load mod-core-user-config-file nil 'nomessage)

(unless orbit-user-snippets-directory
  (setq orbit-user-snippets-directory mod-core-user-snippets-directory))

(defun mod-core--current-project-root ()
  "Return the current project root, or nil when outside a project."
  (when-let* ((project (project-current nil)))
    (project-root project)))

(defun mod-core--path-token-bounds ()
  "Return bounds for the non-whitespace token at point."
  (save-excursion
    (skip-chars-backward "^ \t\n\"'`()[]{}<>")
    (let ((beg (point)))
      (skip-chars-forward "^ \t\n\"'`()[]{}<>")
      (cons beg (point)))))

(defun mod-core--path-token-at-point ()
  "Return the non-whitespace token at point, or nil when empty."
  (pcase-let ((`(,beg . ,end) (mod-core--path-token-bounds)))
    (when (< beg end)
      (buffer-substring-no-properties beg end))))

(defun mod-core--open-file-path (path &optional line)
  "Open PATH, optionally moving to LINE."
  (let ((expanded (expand-file-name (substitute-in-file-name path))))
    (if (fboundp 'mod-context-open-path)
        (mod-context-open-path expanded)
      (find-file expanded))
    (when line
      (goto-char (point-min))
      (forward-line (1- line)))))

(defun mod-core-open-at-point ()
  "Open a URL or file path at point."
  (interactive)
  (if-let* ((url (thing-at-point 'url t)))
      (browse-url url)
    (let ((token (mod-core--path-token-at-point)))
      (unless token
        (user-error "No URL or file path at point"))
      (let ((line nil)
            (path token))
        (when (string-match "\\`\\(.+\\):\\([0-9]+\\)\\'" token)
          (let ((candidate (match-string 1 token))
                (candidate-line (string-to-number (match-string 2 token))))
            (when (file-exists-p (expand-file-name (substitute-in-file-name candidate)))
              (setq path candidate
                    line candidate-line))))
        (unless (file-exists-p (expand-file-name (substitute-in-file-name path)))
          (user-error "No URL or file path at point"))
        (mod-core--open-file-path path line)))))

(defun mod-core--kill-ring-save (text label)
  "Copy TEXT to the kill ring and report LABEL."
  (kill-new text)
  (message "Copied %s: %s" label text))

(defun mod-core-copy-absolute-file-path ()
  "Copy the current buffer's absolute file path."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (mod-core--kill-ring-save (expand-file-name buffer-file-name) "absolute path"))

(defun mod-core-copy-project-relative-file-path ()
  "Copy the current file path relative to the project root when possible."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (let* ((absolute (expand-file-name buffer-file-name))
         (project-root (mod-core--current-project-root))
         (path (if project-root
                   (file-relative-name absolute project-root)
                 absolute)))
    (mod-core--kill-ring-save path "project-relative path")))

(defun mod-core-copy-directory-path ()
  "Copy the current buffer directory path."
  (interactive)
  (let ((dir (expand-file-name (or (and buffer-file-name
                                        (file-name-directory buffer-file-name))
                                   default-directory))))
    (mod-core--kill-ring-save dir "directory path")))

(defun mod-core--linewise-region-bounds ()
  "Return bounds covering the active region or current line."
  (if (use-region-p)
      (let ((beg (save-excursion
                   (goto-char (region-beginning))
                   (line-beginning-position)))
            (end (save-excursion
                   (goto-char (region-end))
                   (if (and (> (region-end) (region-beginning))
                            (= (region-end) (line-beginning-position)))
                       (point)
                     (forward-line 1)
                     (point)))))
        (cons beg end))
    (cons (line-beginning-position)
          (save-excursion
            (forward-line 1)
            (point)))))

(defun mod-core-duplicate-line-or-region ()
  "Duplicate the active region, or the current line when no region is active."
  (interactive)
  (pcase-let ((`(,beg . ,end) (mod-core--linewise-region-bounds)))
    (let ((text (buffer-substring-no-properties beg end)))
      (goto-char end)
      (insert text))))

(defun mod-core-move-line-or-region-down ()
  "Move the active region or current line down by one line."
  (interactive)
  (pcase-let ((`(,beg . ,end) (mod-core--linewise-region-bounds)))
    (save-excursion
      (goto-char end)
      (when (eobp)
        (user-error "Cannot move past end of buffer")))
    (let* ((block (buffer-substring-no-properties beg end))
           (next-end (save-excursion
                       (goto-char end)
                       (forward-line 1)
                       (point)))
           (next-line (buffer-substring-no-properties end next-end)))
      (delete-region beg next-end)
      (goto-char beg)
      (insert next-line block)
      (goto-char (+ beg (length next-line))))))

(defun mod-core-move-line-or-region-up ()
  "Move the active region or current line up by one line."
  (interactive)
  (pcase-let ((`(,beg . ,end) (mod-core--linewise-region-bounds)))
    (when (<= beg (point-min))
      (user-error "Cannot move past beginning of buffer"))
    (let* ((prev-end beg)
           (prev-beg (save-excursion
                       (goto-char prev-end)
                       (forward-line -1)
                       (point)))
           (prev (buffer-substring-no-properties prev-beg prev-end))
           (block (buffer-substring-no-properties beg end)))
      (delete-region prev-beg end)
      (goto-char prev-beg)
      (insert block prev)
      (goto-char prev-beg))))

(defun mod-core--recentf-candidates ()
  "Return recent files, preferring current-project entries first."
  (require 'recentf)
  (let* ((files (cl-remove-if-not #'file-exists-p recentf-list))
         (project-root (mod-core--current-project-root))
         (project-files '())
         (other-files '()))
    (dolist (file files)
      (if (and project-root
               (string-prefix-p (file-truename project-root)
                                (file-truename file)))
          (push file project-files)
        (push file other-files)))
    (append (nreverse project-files) (nreverse other-files))))

(defun mod-core-recentf-open ()
  "Open a recent file, preferring current-project entries first."
  (interactive)
  (let ((candidates (mod-core--recentf-candidates)))
    (unless candidates
      (user-error "No recent files available"))
    (let ((file (completing-read "Recent file: " candidates nil t nil
                                 'mod-core-recentf-history)))
      (if (fboundp 'mod-context-open-path)
          (mod-context-open-path file)
        (find-file file)))))

(defun mod-core-maybe-create-parent-directory ()
  "Prompt to create missing parent directories before saving a file."
  (when-let* ((file buffer-file-name)
              (directory (file-name-directory file))
              ((not (file-directory-p directory))))
    (if (y-or-n-p (format "Directory %s does not exist. Create it? " directory))
        (make-directory directory t)
      (user-error "Parent directory does not exist: %s" directory))))

(add-hook 'before-save-hook #'mod-core-maybe-create-parent-directory)

(when orbit-user-shell
  (setq shell-file-name orbit-user-shell
        explicit-shell-file-name orbit-user-shell))

(setq backup-directory-alist `(("." . ,mod-core-backup-directory))
      auto-save-file-name-transforms `((".*" ,(file-name-as-directory mod-core-auto-save-directory) t))
      auto-save-list-file-prefix (expand-file-name ".saves-" mod-core-auto-save-directory)
      lock-file-name-transforms mod-core-lockfile-transforms
      savehist-file mod-core-savehist-file)

(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" mod-core-config-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order
  '(elpaca :repo "https://github.com/progfolio/elpaca.git"
           :ref nil
           :depth 1
           :inherit ignore
           :files (:defaults "elpaca-test.el" (:exclude "extensions"))
           :build (:not elpaca-activate)))

(let* ((repo (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (bootstrap-ok nil)
       (default-directory repo))
  (add-to-list 'load-path
               (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28)
      (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (get-buffer-create "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process
                                 `("git" nil ,buffer t "clone"
                                   ,@(when-let* ((depth (plist-get order :depth)))
                                       (list (format "--depth=%d" depth) "--no-single-branch"))
                                   ,(plist-get order :repo) ,repo))))
                  ((or (not (plist-get order :ref))
                       (zerop (call-process "git" nil buffer t "checkout"
                                            (plist-get order :ref)))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((mod-core--require-elpaca repo))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn
              (message "%s" (buffer-string))
              (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error)
       (warn "Elpaca bootstrap failed: %s" err)
       (delete-directory repo 'recursive))))
  (setq bootstrap-ok
        (if (require 'elpaca-autoloads nil t)
            t
          (when (mod-core--require-elpaca repo)
            (elpaca-generate-autoloads "elpaca" repo)
            (let ((load-source-file-function nil))
              (load (expand-file-name "elpaca-autoloads" repo) nil 'nomessage))
            t)))
  (when bootstrap-ok
    (add-hook 'after-init-hook #'elpaca-process-queues)
    (eval `(elpaca ,elpaca-order))
    (elpaca exec-path-from-shell
      (when (mod-core-gui-shell-environment-p)
        (setq exec-path-from-shell-arguments '("-l"))
        (exec-path-from-shell-copy-envs '("PATH" "MANPATH"))))
    (elpaca elpaca-use-package
      (elpaca-use-package-mode))
    (setq elpaca-use-package-by-default t)))

(provide 'mod-core)

;;; mod-core.el ends here
