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
(defconst mod-core-custom-file
  (expand-file-name "custom.el" mod-core-var-directory))
(defconst mod-core-package-directory
  (expand-file-name "packages/" mod-core-var-directory))
(defconst mod-core-package-gnupg-directory
  (expand-file-name "package-gnupg/" mod-core-var-directory))
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
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "config.example.el" mod-core-config-directory))
    (buffer-string)))

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
(defvar orbit-user-tcl-auto-fold-doxygen-comments nil)
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

(defvar orbit-user-roam-directory nil
  "Directory for org-roam nodes.
Defaults to roam/ inside the org directory when nil.")

(defvar orbit-user-forge-gitlab-host nil
  "Hostname of the self-hosted GitLab instance used by forge.
Example: \"gitlab.example.com\".
Also requires an entry in ~/.authinfo:
  machine gitlab.example.com login USERNAME^forge password YOUR_PAT")

(defvar orbit-user-forge-gitlab-username nil
  "GitLab username for forge display purposes.
Credentials are read from ~/.authinfo, not from this variable.")

(defvar orbit-user-delta-program nil
  "Path to the delta diff-highlight tool.
Leave nil to locate delta on PATH automatically.")

(defvar orbit-user-orbit-theme 'orbit-dark
  "Initial orbit theme.  One of \\='orbit-dark or \\='orbit-light.
Toggle at runtime with SPC t T.")

(defvar orbit-user-nerd-fonts nil
  "When non-nil, use Nerd Fonts powerline glyph separators (\\xe0b0 / \\xe0b2).
Requires a patched Nerd Font installed (e.g. JetBrainsMono Nerd Font Mono).")

(defvar mod-core-recentf-history nil
  "Minibuffer history for recent file selection.")

(defun mod-core-gui-shell-environment-p ()
  "Return non-nil when shell environment import should run."
  (and (memq system-type '(darwin gnu/linux))
       (or (display-graphic-p)
           (daemonp))))

(defun mod-core-import-shell-environment ()
  "Import PATH-like variables from the user's login shell.
If shell startup output or shell-specific JSON formatting breaks
`exec-path-from-shell', keep startup going and show a clear warning instead of
aborting init."
  (when (mod-core-gui-shell-environment-p)
    (setq exec-path-from-shell-arguments '("-l"))
    (condition-case err
        (exec-path-from-shell-copy-envs '("PATH" "MANPATH"))
      (error
       (display-warning
        'mod-core
        (concat
         "Shell environment import failed; orbit-emacs will continue with the "
         "current PATH. Check shell startup output or set orbit-user-shell. "
         "Original error: "
         (error-message-string err))
        :warning)))))

(defun mod-core-ensure-user-files ()
  "Ensure the user-local orbit-emacs files exist."
  (make-directory mod-core-user-directory t)
  (make-directory mod-core-user-snippets-directory t)
  (unless (file-exists-p mod-core-user-config-file)
    (write-region mod-core-user-config-template nil mod-core-user-config-file nil 'silent)))

(dolist (dir (list mod-core-var-directory
                   mod-core-backup-directory
                   mod-core-auto-save-directory
                   mod-core-lockfile-directory
                   mod-core-package-directory
                   mod-core-package-gnupg-directory))
  (make-directory dir t))

(mod-core-ensure-user-files)
(load mod-core-user-config-file nil 'nomessage)
(setq custom-file mod-core-custom-file)
(load custom-file 'noerror 'nomessage)

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

(require 'package)
(require 'package-vc)

(setq package-user-dir mod-core-package-directory
      package-archives '(("melpa" . "https://melpa.org/packages/"))
      package-archive-priorities '(("melpa" . 30)))

(when (boundp 'package-gnupghome-dir)
  (setq package-gnupghome-dir mod-core-package-gnupg-directory))

(package-initialize)

(defconst mod-core-package-vc-recipes
  '((compat :vc-backend Git :url "https://github.com/emacs-compat/compat")
    (dape :vc-backend Git :url "https://github.com/svaante/dape")
    (eat :vc-backend Git :url "https://codeberg.org/akib/emacs-eat.git"))
  "VC package recipes used when MELPA alone cannot satisfy a dependency.")

(defun mod-core--package-available-p (package)
  "Return non-nil when PACKAGE is installed or built into Emacs."
  (or (package-installed-p package)
      (package-built-in-p package)))

(defun mod-core--package-vc-recipe (package)
  "Return the VC recipe plist for PACKAGE, or nil when none is defined."
  (cdr (assq package mod-core-package-vc-recipes)))

(defun mod-core-ensure-package-installed (package)
  "Install PACKAGE with `package.el' when it is not already available."
  (unless (mod-core--package-available-p package)
    (if-let* ((recipe (mod-core--package-vc-recipe package)))
        (package-vc-install (cons package recipe))
      (unless package-archive-contents
        (package-refresh-contents))
      (package-install package))))

(mod-core-ensure-package-installed 'use-package)
(mod-core-ensure-package-installed 'compat)
(mod-core-ensure-package-installed 'dape)
(mod-core-ensure-package-installed 'eat)
(require 'use-package)
(setq use-package-always-ensure t)

(use-package exec-path-from-shell
  :if (mod-core-gui-shell-environment-p)
  :config
  (mod-core-import-shell-environment))

(provide 'mod-core)

;;; mod-core.el ends here
