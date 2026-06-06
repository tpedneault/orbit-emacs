;;; mod-core.el --- Core bootstrap -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'browse-url)
(require 'project)
(require 'thingatpt)

(declare-function orbit-context-open-path "orbit-context")

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
(defconst mod-core-elpaca-directory
  (expand-file-name "elpaca/" mod-core-var-directory))
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
(defvar orbit-user-font-preset nil)
(defvar orbit-user-font-presets nil)
(defvar orbit-user-font-resize-keys t)
(defvar orbit-user-font-resize-step 10)
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
(defvar orbit-user-wslg-frame-refresh t)
(defvar orbit-user-tcl-indent-width 3)
(defvar orbit-user-tcl-fill-column 120)
(defvar orbit-user-tcl-use-tabs nil)
(defvar orbit-user-enable-whitespace t)
(defvar orbit-user-enable-hl-line t)
(defvar orbit-user-org-pretty t)
(defvar orbit-user-org-variable-pitch nil)
(defvar orbit-user-org-auto-align-tables t)
(defvar orbit-user-evil-pulse-enabled t)
(defvar orbit-user-evil-pulse-interval 0.04)
(defvar orbit-user-evil-pulse-alphas '(0.82 0.62 0.44 0.28 0.15 0.06))
(defvar orbit-user-evil-pulse-color nil)
(defvar orbit-user-tcl-enable-fill-column-indicator 'inherit)
(defvar orbit-user-tcl-enable-whitespace 'inherit)
(defvar orbit-user-tcl-enable-hl-line 'inherit)
(defvar orbit-user-tcl-auto-fold-definitions nil)
(defvar orbit-user-tcl-auto-fold-doxygen-comments nil)
(defvar orbit-user-tcl-known-symbols-file nil)
(defvar orbit-user-tcl-doxygen-xml-directory nil)
(defvar orbit-user-doxygen-program nil)
(defvar orbit-user-doxygen-config-file nil)
(defvar orbit-user-mib-roots nil)
(defvar orbit-user-mib-icd-version "7.2")
(defvar orbit-user-mib-telecommand-template
  "telecommand_send PUS_T={type} PUS_ST={stype} APID={apid} MNEMO={mnemo} ARGUMENTS=[{arguments}]")
(defvar orbit-user-mib-telecommand-argument-template "{name}={value}")
(defvar orbit-user-mib-telecommand-argument-separator ", ")
(defvar orbit-user-jira-base-url nil)
(defvar orbit-user-jira-api-prefix "/rest/api/2")
(defvar orbit-user-jira-project-key nil)
(defvar orbit-user-jira-username nil)
(defvar orbit-user-jira-jql nil)
(defvar orbit-user-jira-org-file nil)
(defvar orbit-user-jira-token-command nil)
(defvar orbit-user-jira-pat-env nil)

(defvar orbit-keybinding-profile 'vim
  "Editing/keybinding profile.
Use \\='vim for Evil modal editing and the SPC leader.
Use \\='standard for conventional Emacs editing with the C-; Orbit prefix.")

(defvar orbit-standard-menu-bar nil
  "Whether the Orbit menu bar is shown.
This controls the native platform menu bar, not the custom Orbit menu strip.
Use \\='auto to show it for `orbit-keybinding-profile' \\='standard only.
Use t to always show it, or nil to always hide it.")

(defvar orbit-standard-cua-keys 'auto
  "Whether Windows-style CUA copy/cut/paste keys are enabled.
Use \\='auto to enable them for `orbit-keybinding-profile' \\='standard only.
Use t to always enable them, or nil to always keep them disabled.")

(defvar orbit-menu-enabled 'auto
  "Whether the custom Orbit menu strip is enabled.
Use \\='auto to enable it for `orbit-keybinding-profile' \\='standard only.
Use t to always enable it, or nil to always keep it disabled.")

(defvar orbit-menu-dropdown-height 14
  "Maximum height, in lines, for Orbit menu dropdown windows.")

(defvar orbit-menu-show-key-hints t
  "When non-nil, show shortcut hints beside Orbit menu commands.")

(defun mod-core-vim-profile-p ()
  "Return non-nil when Orbit should use the Vim/Evil profile."
  (not (eq orbit-keybinding-profile 'standard)))

(defun mod-core-standard-profile-p ()
  "Return non-nil when Orbit should use the standard Emacs profile."
  (eq orbit-keybinding-profile 'standard))

(defun mod-core-menu-bar-enabled-p ()
  "Return non-nil when the menu bar should be visible."
  (or (eq orbit-standard-menu-bar t)
      (and (eq orbit-standard-menu-bar 'auto)
           (mod-core-standard-profile-p))))

(defun mod-core-cua-keys-enabled-p ()
  "Return non-nil when Windows-style CUA keys should be enabled."
  (or (eq orbit-standard-cua-keys t)
      (and (eq orbit-standard-cua-keys 'auto)
           (mod-core-standard-profile-p))))

(defun mod-core-orbit-menu-enabled-p ()
  "Return non-nil when the custom Orbit menu strip should be visible."
  (or (eq orbit-menu-enabled t)
      (and (eq orbit-menu-enabled 'auto)
           (mod-core-standard-profile-p))))

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

(defvar orbit-user-treemacs-tags-max-file-size (* 2 1024 1024)
  "Maximum file size, in bytes, that Treemacs may index for function tags.
Set to nil to disable the guard.")

(defvar orbit-user-treemacs-tags-max-items 2000
  "Maximum number of function tags Treemacs may render for one file.
Set to nil to disable the guard.")

(defvar orbit-user-orbit-theme 'orbit-dark
  "Initial orbit theme.
One of \\='orbit-dark, \\='orbit-light, \\='orbit-retro-amber,
\\='orbit-retro-green, \\='orbit-retro-blue, \\='orbit-retro-temple,
\\='orbit-retro-paper, or \\='orbit-retro-sky.
Choose at runtime with SPC t T.")

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
                   mod-core-elpaca-directory))
  (make-directory dir t))

(mod-core-ensure-user-files)
(load mod-core-user-config-file nil 'nomessage)
(setq custom-file mod-core-custom-file)
(load custom-file 'noerror 'nomessage)
(setq use-short-answers t)

(when (mod-core-cua-keys-enabled-p)
  (require 'cua-base)
  (setq cua-enable-cua-keys t
        cua-delete-selection t)
  (cua-mode 1))

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
    (if (fboundp 'orbit-context-open-path)
        (orbit-context-open-path expanded)
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
      (if (fboundp 'orbit-context-open-path)
          (orbit-context-open-path file)
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
(defvar elpaca-directory mod-core-elpaca-directory)
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
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop
                    (apply #'call-process
                           `("git" nil ,buffer t "clone"
                             ,@(when-let* ((depth (plist-get order :depth)))
                                 (list (format "--depth=%d" depth)
                                       "--no-single-branch"))
                             ,(plist-get order :repo)
                             ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil
                                        "-Q" "-L" "." "--batch"
                                        "--eval"
                                        "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn
              (message "%s" (buffer-string))
              (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error)
       (warn "%s" err)
       (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil))
      (load "./elpaca-autoloads"))))

(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;; Corporate networks often block GNU/NonGNU ELPA.  Keep Elpaca on Git-backed
;; menus and explicit source recipes instead of package archive downloads.
(setq elpaca-menu-functions
      '(elpaca-menu-lock-file
        elpaca-menu-extensions
        elpaca-menu-melpa
        elpaca-menu-declarations))

;; Explicit Git recipes for packages that should not be fetched from ELPA.
(elpaca (use-package :repo "https://github.com/jwiegley/use-package.git" :wait t))
(elpaca (compat :repo "https://github.com/emacs-compat/compat.git" :wait t))
(elpaca (dape :repo "https://github.com/svaante/dape.git" :wait t))
(elpaca (vterm :repo "https://github.com/akermu/emacs-libvterm.git" :wait t))

(require 'use-package)
(setq use-package-always-ensure t)

(elpaca elpaca-use-package
  (elpaca-use-package-mode))

(use-package exec-path-from-shell
  :if (mod-core-gui-shell-environment-p)
  :config
  (mod-core-import-shell-environment))

(provide 'mod-core)

;;; mod-core.el ends here
