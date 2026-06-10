;;; mod-dired.el --- Dired and project tree foundation -*- lexical-binding: t; -*-

(require 'dired)
(require 'dired-x)
(require 'cl-lib)
(require 'imenu)
(require 'project)

(eval-when-compile
  (require 'evil nil t))

(declare-function treemacs "treemacs" (&optional arg))
(declare-function treemacs-current-visibility "treemacs" ())
(declare-function treemacs-add-and-display-current-project-exclusively "treemacs")
(declare-function treemacs-find-file "treemacs" (&optional arg file))
(declare-function treemacs-create-icon "treemacs-icons" (&rest args))
(declare-function treemacs-load-theme "treemacs-themes" (name))
(declare-function treemacs-modify-theme "treemacs-themes" (theme &rest args))
(declare-function treemacs--get-imenu-index "treemacs-tags" (file))
(declare-function treemacs--call-imenu-and-goto-tag "treemacs-tags" (tag-path &optional org?))
(declare-function treemacs-visit-node-horizontal-split "treemacs")
(declare-function treemacs-visit-node-in-most-recently-used-window "treemacs")
(declare-function treemacs-visit-node-vertical-split "treemacs")
(declare-function treemacs-add-project-to-workspace "treemacs-interface" (path &optional name))
(declare-function dirvish-side "dirvish-side" (&optional path))
(declare-function dirvish-side-follow-mode "dirvish-side" (&optional arg))
(declare-function dirvish-side--session-visible-p "dirvish-side")
(declare-function dirvish-curr "dirvish")
(declare-function dv-type "dirvish")
(declare-function dirvish-dispatch "dirvish-extras")
(declare-function dirvish-mark-menu "dirvish-extras")
(declare-function dirvish-quicksort "dirvish-extras")
(declare-function dirvish-yank-menu "dirvish-yank")
(declare-function dirvish-subtree-toggle "dirvish-subtree")
(declare-function mod-core-wsl-windows-path-p "mod-core" (&optional path))

(setq delete-by-moving-to-trash t
      dired-dwim-target t
      dired-recursive-copies 'always
      dired-recursive-deletes 'top
      dired-omit-files "\\`[.]\\{1,2\\}\\'")

(defconst mod-dired--treemacs-tcl-proc-regexp
  "^[[:blank:]]*proc[[:blank:]]+\\(\\(?:::\\)?[[:alnum:]_:]+\\)[[:blank:]]+"
  "Regexp matching Tcl proc definitions for Treemacs tag indexing.")

(defconst mod-dired--treemacs-tcl-namespace-regexp
  "^[[:blank:]]*namespace[[:blank:]]+eval[[:blank:]]+\\(\\(?:::\\)?[[:alnum:]_:]+\\)[[:blank:]]*{"
  "Regexp matching Tcl namespace definitions for Treemacs tag indexing.")

(let ((gls (executable-find "gls"))
      (ls (executable-find "ls")))
  (setq insert-directory-program (or gls ls))
  (setq dired-use-ls-dired (and gls t))
  (setq dired-listing-switches
        (if (or gls (eq system-type 'gnu/linux))
            "--all --long --human-readable --group-directories-first"
          "-alh")))

(put 'dired-find-alternate-file 'disabled nil)

(defun mod-dired-here ()
  "Open Dired in the current default directory."
  (interactive)
  (dired default-directory))

(defun mod-dired-jump ()
  "Jump to a Dired buffer for the current file or directory."
  (interactive)
  (dired-jump))

(defun mod-dired--project-root ()
  "Return the current project root, or nil outside a project."
  (when-let* ((project (project-current nil)))
    (project-root project)))

(defun mod-dired--wsl-windows-path-p (&optional path)
  "Return non-nil when PATH should use conservative WSL Windows handling."
  (and (fboundp 'mod-core-wsl-windows-path-p)
       (mod-core-wsl-windows-path-p path)))

(defun mod-dired--current-root-for-tree ()
  "Return the best root for file-tree display without expensive probing."
  (file-name-as-directory
   (expand-file-name
    (or (and buffer-file-name (file-name-directory buffer-file-name))
        default-directory))))

(defun mod-dired--sidebar-root ()
  "Return the root directory to use for the configured project sidebar."
  (file-name-as-directory
   (expand-file-name
    (or (unless (mod-dired--wsl-windows-path-p
                 (or buffer-file-name default-directory))
          (mod-dired--project-root))
        (mod-dired--current-root-for-tree)))))

(defun mod-dired--dirvish-attributes-for-path (&optional path side)
  "Return Dirvish attributes suitable for PATH.
When SIDE is non-nil, return attributes for the project sidebar."
  (cond
   ((mod-dired--wsl-windows-path-p path)
    (if side
        '(subtree-state nerd-icons)
      '(subtree-state nerd-icons collapse file-time file-size)))
   (side
    '(subtree-state nerd-icons))
   (t
    '(vc-state subtree-state nerd-icons collapse file-time file-size))))

(defun mod-dired--configure-dirvish-for-path (&optional path)
  "Apply Dirvish display settings suitable for PATH."
  (setq dirvish-attributes
        (mod-dired--dirvish-attributes-for-path path nil)
        dirvish-side-attributes
        (mod-dired--dirvish-attributes-for-path path t))
  (when (fboundp 'dirvish-side-follow-mode)
    (dirvish-side-follow-mode
     (if (mod-dired--wsl-windows-path-p path) -1 1))))

(defun mod-dired--configure-dirvish-for-current-buffer ()
  "Apply path-sensitive Dirvish settings for the current Dired buffer."
  (when (featurep 'dirvish)
    (mod-dired--configure-dirvish-for-path default-directory)))

(defun mod-dired--dirvish-side-buffer-p ()
  "Return non-nil when the current buffer belongs to a Dirvish side session."
  (and (fboundp 'dirvish-curr)
       (fboundp 'dv-type)
       (when-let* ((dv (dirvish-curr)))
         (eq (dv-type dv) 'side))))

(defun mod-dired--setup-dirvish-side-buffer ()
  "Make Dirvish side buffers look like quiet project trees."
  (when (mod-dired--dirvish-side-buffer-p)
    (when (bound-and-true-p diredfl-mode)
      (diredfl-mode -1))
    (setq-local hl-line-face 'hl-line)
    (setq-local face-remapping-alist
                (append '((dirvish-hl-line hl-line)
                          (dirvish-hl-line-inactive hl-line)
                          (dired-directory default))
                        face-remapping-alist))))

(defun mod-dired--dot-directory-listing-line-p (line)
  "Return non-nil when LINE is an ls entry for . or ..."
  (string-match-p "[[:space:]]\\.\\.?[[:space:]]*\\'" line))

(defun mod-dired--strip-dot-directory-listing-lines (listing)
  "Remove . and .. entries from a Dirvish subtree LISTING."
  (mapconcat #'identity
             (cl-remove-if #'mod-dired--dot-directory-listing-line-p
                           (split-string listing "\n"))
             "\n"))

(defun mod-dired--dirvish-subtree-readin-without-dot-dirs (orig dir)
  "Call ORIG for DIR, then remove . and .. entries from the listing."
  (mod-dired--strip-dot-directory-listing-lines
   (funcall orig dir)))

(defun mod-dired-toggle-subtree ()
  "Toggle a Dirvish subtree only when point is on a directory."
  (interactive)
  (let ((file (dired-get-filename nil t)))
    (cond
     ((not file)
      (message "No file at point"))
     ((file-directory-p file)
      (dirvish-subtree-toggle))
     (t
      (message "TAB expands directories; use RET to open files")))))

(defun mod-dired--setup-dired-buffer ()
  "Apply Orbit's quiet Dired presentation defaults."
  (hl-line-mode 1)
  (auto-revert-mode 1)
  (setq-local display-line-numbers nil)
  (when (fboundp 'display-line-numbers-mode)
    (display-line-numbers-mode -1))
  (when (fboundp 'dired-omit-mode)
    (dired-omit-mode 1))
  (mod-dired--configure-dirvish-for-current-buffer))

(defun mod-dired--dirvish-sidebar-toggle ()
  "Toggle the Dirvish sidebar at the current project or directory root."
  (require 'dirvish)
  (require 'dirvish-side)
  (let ((root (mod-dired--sidebar-root)))
    (mod-dired--configure-dirvish-for-path root)
    (if (and (fboundp 'dirvish-side--session-visible-p)
             (dirvish-side--session-visible-p))
        (dirvish-side)
      (dirvish-side root))))

(defun mod-dired--treemacs-disable-rich-modes ()
  "Disable Treemacs features that are risky across the WSL Windows bridge."
  (setq treemacs-follow-after-init nil
        treemacs-collapse-dirs 0)
  (when (bound-and-true-p treemacs-follow-mode)
    (treemacs-follow-mode -1))
  (when (bound-and-true-p treemacs-filewatch-mode)
    (treemacs-filewatch-mode -1))
  (when (bound-and-true-p treemacs-git-mode)
    (treemacs-git-mode -1))
  (when (bound-and-true-p treemacs-hide-gitignored-files-mode)
    (treemacs-hide-gitignored-files-mode -1)))

(defun mod-dired--treemacs-enable-rich-modes ()
  "Enable the normal Treemacs feature set for native Linux paths."
  (setq treemacs-follow-after-init t
        treemacs-collapse-dirs 3)
  (treemacs-follow-mode 1)
  (treemacs-filewatch-mode 1)
  (treemacs-git-mode 'deferred)
  (when (fboundp 'treemacs-hide-gitignored-files-mode)
    (treemacs-hide-gitignored-files-mode 1)))

(defun mod-dired--configure-treemacs-for-path (&optional path)
  "Apply a Treemacs feature profile suitable for PATH."
  (require 'treemacs)
  (if (mod-dired--wsl-windows-path-p path)
      (mod-dired--treemacs-disable-rich-modes)
    (mod-dired--treemacs-enable-rich-modes)))

(defun mod-dired--treemacs-focus-project ()
  "Focus Treemacs on the current project when possible."
  (mod-dired--configure-treemacs-for-path
   (or buffer-file-name default-directory))
  (when-let* ((root (mod-dired--project-root)))
    (let ((default-directory root))
      (cond
       ((fboundp 'treemacs-display-current-project-exclusively)
        (ignore-errors
          (treemacs-display-current-project-exclusively)))
       ((fboundp 'treemacs-add-and-display-current-project-exclusively)
        (ignore-errors
          (treemacs-add-and-display-current-project-exclusively)))))
    (when (and buffer-file-name (fboundp 'treemacs-find-file))
      (ignore-errors
        (treemacs-find-file)))))

(defun mod-dired--treemacs-open-plain-root (root)
  "Open Treemacs at ROOT without project, Git, follow, or filewatch probing."
  (mod-dired--configure-treemacs-for-path root)
  (let ((default-directory root))
    (treemacs)
    (when (fboundp 'treemacs-add-project-to-workspace)
      (ignore-errors
        (treemacs-add-project-to-workspace
         root
         (file-name-nondirectory (directory-file-name root)))))))

(defun mod-dired--treemacs-sidebar-toggle ()
  "Toggle the Treemacs project sidebar."
  (interactive)
  (require 'treemacs)
  (if (eq (treemacs-current-visibility) 'visible)
      (treemacs)
    (if (mod-dired--wsl-windows-path-p (or buffer-file-name default-directory))
        (mod-dired--treemacs-open-plain-root (mod-dired--current-root-for-tree))
      (mod-dired--configure-treemacs-for-path (or buffer-file-name default-directory))
      (if (mod-dired--project-root)
          (mod-dired--treemacs-focus-project)
        (treemacs)))))

(defun mod-dired-project-sidebar-toggle ()
  "Toggle the configured project file sidebar."
  (interactive)
  (pcase orbit-user-sidebar-backend
    ('dirvish
     (mod-dired--dirvish-sidebar-toggle))
    ('treemacs
     (mod-dired--treemacs-sidebar-toggle))
    (_
     (user-error "Unknown orbit sidebar backend: %S" orbit-user-sidebar-backend))))

(add-hook 'dired-mode-hook #'mod-dired--setup-dired-buffer)

(define-key dired-mode-map (kbd "TAB") #'mod-dired-toggle-subtree)
(define-key dired-mode-map (kbd "<tab>") #'mod-dired-toggle-subtree)

(defun mod-dired-setup-treemacs-buffer ()
  "Make Treemacs denser and quieter than a normal editing buffer."
  (when (fboundp 'display-line-numbers-mode)
    (display-line-numbers-mode -1))
  (setq-local line-spacing nil
              cursor-type nil)
  (when (boundp 'display-line-numbers)
    (setq-local display-line-numbers nil)))

(defun mod-dired--treemacs-noise-file-p (filename _path)
  "Return non-nil when FILENAME is generated noise for Treemacs purposes."
  (or (member filename '("TAGS" ".DS_Store"))
      (string-match-p "\\`#.*#\\'" filename)
      (string-match-p "\\`\\.?#.*\\~\\'" filename)
      (string-match-p "\\.elc\\'" filename)
      (string-match-p "\\.pyc\\'" filename)))

(defun mod-dired-setup-treemacs-icons ()
  "Override a few Treemacs file icons to better match Orbit workflows."
  (treemacs-modify-theme "Default"
    :config
    (treemacs-create-icon
     :file "vsc/lisp.png"
     :extensions ("tcl" "tm" "xdc" "sdc" "upf")
     :fallback (propertize "{} " 'face 'font-lock-keyword-face))))

(defun mod-dired--treemacs-tag-path (btn)
  "Return the Treemacs tag path stored on BTN, or nil."
  (when-let* ((buffer (marker-buffer btn)))
    (with-current-buffer buffer
      (get-text-property btn :path))))

(defun mod-dired--tcl-file-p (file)
  "Return non-nil when FILE is a Tcl-family source file."
  (member (downcase (or (file-name-extension file) ""))
          '("tcl" "tm" "xdc" "sdc" "upf")))

(defun mod-dired--treemacs-file-too-large-p (file)
  "Return non-nil when FILE should not be indexed for Treemacs tags."
  (and orbit-user-treemacs-tags-max-file-size
       (file-regular-p file)
       (let ((attrs (file-attributes file)))
         (and attrs
              (> (file-attribute-size attrs)
                 orbit-user-treemacs-tags-max-file-size)))))

(defun mod-dired--treemacs-count-tags (index)
  "Return the number of leaf tags in INDEX."
  (cl-labels ((count-item
               (item)
               (if (imenu--subalist-p item)
                   (mod-dired--treemacs-count-tags (cdr item))
                 1)))
    (cl-loop for item in index sum (count-item item))))

(defun mod-dired--treemacs-tags-too-many-p (index)
  "Return non-nil when INDEX has too many tags for Treemacs to render safely."
  (and orbit-user-treemacs-tags-max-items
       (> (mod-dired--treemacs-count-tags index)
          orbit-user-treemacs-tags-max-items)))

(defun mod-dired--treemacs-tcl-display-name (symbol)
  "Return a compact display name for Tcl SYMBOL."
  (if (string-match "::\\([^:]+\\)\\'" symbol)
      (match-string 1 symbol)
    symbol))

(defun mod-dired--treemacs-limited-push-tag (name pos tags count)
  "Push NAME and POS into TAGS while COUNT is below the configured limit."
  (if (and orbit-user-treemacs-tags-max-items
           (>= (car count) orbit-user-treemacs-tags-max-items))
      tags
    (cl-incf (car count))
    (push (cons (mod-dired--treemacs-tcl-display-name name) pos) tags)))

(defun mod-dired--treemacs-tag-limit-reached-p (count)
  "Return non-nil when COUNT has reached the configured tag item limit."
  (and orbit-user-treemacs-tags-max-items
       (>= (car count) orbit-user-treemacs-tags-max-items)))

(defun mod-dired--treemacs-tcl-imenu-index (file)
  "Return a fast Treemacs tag index for Tcl-family FILE."
  (let (functions namespaces
        (count (list 0)))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (and (not (mod-dired--treemacs-tag-limit-reached-p count))
                  (re-search-forward mod-dired--treemacs-tcl-namespace-regexp nil t))
        (setq namespaces
              (mod-dired--treemacs-limited-push-tag
               (match-string-no-properties 1)
               (match-beginning 1)
               namespaces
               count)))
      (goto-char (point-min))
      (while (and (not (mod-dired--treemacs-tag-limit-reached-p count))
                  (re-search-forward mod-dired--treemacs-tcl-proc-regexp nil t))
        (setq functions
              (mod-dired--treemacs-limited-push-tag
               (match-string-no-properties 1)
               (match-beginning 1)
               functions
               count))))
    (let (index)
      (when functions
        (push (cons "Functions" (nreverse functions)) index))
      (when namespaces
        (push (cons "Namespaces" (nreverse namespaces)) index))
      (when (mod-dired--treemacs-tag-limit-reached-p count)
        (message "Treemacs tags capped at %d for %s"
                 orbit-user-treemacs-tags-max-items
                 file))
      (nreverse index))))

(defun mod-dired--treemacs-safe-imenu-index (orig file)
  "Guard Treemacs tag indexing for FILE before calling ORIG."
  (cond
   ((mod-dired--treemacs-file-too-large-p file)
    (message "Treemacs tags skipped for large file: %s" file)
    nil)
   ((mod-dired--tcl-file-p file)
    (mod-dired--treemacs-tcl-imenu-index file))
   (t
    (let ((index (funcall orig file)))
      (if (and index (mod-dired--treemacs-tags-too-many-p index))
          (progn
            (message "Treemacs tags skipped for noisy file: %s" file)
            nil)
        index)))))

(defun mod-dired--treemacs-find-tcl-tag (file path tag)
  "Jump to Tcl TAG in FILE based on Treemacs PATH.
PATH is the category path inside the Treemacs tag index, such as
`(\"Functions\")' or `(\"Namespaces\")'."
  (let* ((escaped-tag (regexp-quote tag))
         (regexp
          (if (member "Namespaces" path)
              (format
               "^[[:blank:]]*namespace[[:blank:]]+eval[[:blank:]]+\\(?:\\(?:::\\)?[[:alnum:]_:]*::\\)?%s\\(?:[[:blank:]]*{\\|[[:blank:]]\\|$\\)"
               escaped-tag)
            (format
             "^[[:blank:]]*proc[[:blank:]]+\\(?:\\(?:::\\)?[[:alnum:]_:]*::\\)?%s\\(?:[[:blank:]]\\|$\\)"
             escaped-tag))))
    (find-file file)
    (goto-char (point-min))
    (when (re-search-forward regexp nil t)
      (goto-char (match-beginning 0))
      (recenter)
      t)))

(defun mod-dired--treemacs-call-imenu-fallback (orig tag-path &optional org?)
  "Use a Tcl-specific tag search fallback before ORIG for TAG-PATH."
  (let* ((file (car tag-path))
         (path (-butlast (cdr tag-path)))
         (tag (-last-item tag-path)))
    (if (and (stringp file)
             (stringp tag)
             (mod-dired--tcl-file-p file)
             (mod-dired--treemacs-find-tcl-tag file path tag))
        t
      (funcall orig tag-path org?))))

(defun mod-dired--treemacs-goto-tag-fallback (orig btn)
  "Retry Treemacs tag jumps when BTN has no usable stored position."
  (condition-case err
      (funcall orig btn)
    (wrong-type-argument
     (if (and (eq (nth 0 err) 'wrong-type-argument)
              (eq (nth 1 err) 'integer-or-marker-p)
              (null (nth 2 err)))
         (if-let ((tag-path (mod-dired--treemacs-tag-path btn)))
             (treemacs--call-imenu-and-goto-tag tag-path)
           (signal (car err) (cdr err)))
       (signal (car err) (cdr err))))))

(defun mod-dired-setup-evil ()
  "Install Evil-style Dired navigation keys."
  (when (fboundp 'evil-define-key)
    (evil-define-key 'normal dired-mode-map
      "h" #'dired-up-directory
      "l" #'dired-find-file
      (kbd "RET") #'dired-find-file
      "q" #'quit-window
      "m" #'dired-mark
      "u" #'dired-unmark
      "U" #'dired-unmark-all-marks
      "R" #'dired-do-rename
      "D" #'dired-do-delete
      "C" #'dired-do-copy
      "+" #'dired-create-directory
      (kbd "TAB") #'mod-dired-toggle-subtree)))

(defun mod-dired-setup-treemacs-evil ()
  "Install a few Orbit-friendly Treemacs window actions."
  (when (and (fboundp 'evil-define-key)
             (boundp 'treemacs-mode-map))
    (evil-define-key 'treemacs treemacs-mode-map
      "v" #'treemacs-visit-node-vertical-split
      "s" #'treemacs-visit-node-horizontal-split
      "o" #'treemacs-visit-node-in-most-recently-used-window)))

(with-eval-after-load 'evil
  (mod-dired-setup-evil))

(with-eval-after-load 'treemacs
  (mod-dired-setup-treemacs-evil))

(use-package nerd-icons
  :ensure (:wait t)
  :demand t)

(use-package diredfl
  :ensure (:wait t)
  :demand t
  :hook ((dired-mode . diredfl-mode)
         (dirvish-directory-view-mode . diredfl-mode)))

(use-package dirvish
  :ensure (:wait t)
  :demand t
  :init
  (setq dirvish-cache-dir (expand-file-name "dirvish/" mod-core-var-directory)
        dirvish-attributes '(nerd-icons collapse file-time file-size)
        dirvish-hide-details t
        dirvish-hide-cursor t
        dirvish-use-header-line t
        dirvish-use-mode-line t
        dirvish-mode-line-format '(:left (sort omit symlink)
                                   :right (index))
        dirvish-header-line-format '(:left (path) :right ())
        dirvish-side-width 34
        dirvish-side-attributes '(subtree-state nerd-icons)
        dirvish-side-display-alist '((side . left) (slot . -1))
        dirvish-side-window-parameters '((no-delete-other-windows . t))
        dirvish-side-header-line-format '(:left (project))
        dirvish-side-mode-line-format nil
        dirvish-side-auto-expand t
        dirvish-large-directory-threshold 20000)
  :config
  (when-let* ((dirvish-file (locate-library "dirvish"))
              (extension-dir (expand-file-name "extensions/"
                                               (file-name-directory dirvish-file)))
              ((file-directory-p extension-dir)))
    (add-to-list 'load-path extension-dir))
  (dirvish-override-dired-mode 1)
  (add-hook 'dirvish-setup-hook #'mod-dired--setup-dirvish-side-buffer)
  (add-hook 'dirvish-after-revert-hook #'mod-dired--setup-dirvish-side-buffer)
  (define-key dirvish-mode-map (kbd "h") #'dired-up-directory)
  (define-key dirvish-mode-map (kbd "l") #'dired-find-file)
  (define-key dirvish-mode-map (kbd "RET") #'dired-find-file)
  (define-key dirvish-mode-map (kbd "q") #'dirvish-quit)
  (define-key dirvish-mode-map (kbd "m") #'dired-mark)
  (define-key dirvish-mode-map (kbd "u") #'dired-unmark)
  (define-key dirvish-mode-map (kbd "U") #'dired-unmark-all-marks)
  (define-key dirvish-mode-map (kbd "R") #'dired-do-rename)
  (define-key dirvish-mode-map (kbd "D") #'dired-do-delete)
  (define-key dirvish-mode-map (kbd "C") #'dired-do-copy)
  (define-key dirvish-mode-map (kbd "+") #'dired-create-directory)
  (define-key dirvish-mode-map (kbd "TAB") #'mod-dired-toggle-subtree)
  (define-key dirvish-mode-map (kbd "?") #'dirvish-dispatch)
  (define-key dirvish-mode-map (kbd "s") #'dirvish-quicksort)
  (define-key dirvish-mode-map (kbd "y") #'dirvish-yank-menu)
  (define-key dirvish-mode-map (kbd "*") #'dirvish-mark-menu))

(with-eval-after-load 'dirvish-subtree
  (advice-add 'dirvish-subtree--readin
              :around #'mod-dired--dirvish-subtree-readin-without-dot-dirs))

(use-package treemacs
  :ensure t
  :defer t
  :init
  (setq treemacs-width 34
        treemacs-position 'left
        treemacs-indentation 1
        treemacs-indentation-string " "
        treemacs-follow-after-init nil
        treemacs-show-hidden-files t
        treemacs-move-forward-on-expand t
        treemacs-silent-filewatch t
        treemacs-space-between-root-nodes nil
        treemacs-sorting 'alphabetic-case-insensitive-asc
        treemacs-user-mode-line-format nil
        treemacs-collapse-dirs 0
        treemacs-git-mode nil)
  :config
  (treemacs-fringe-indicator-mode 'always)
  (add-to-list 'treemacs-ignored-file-predicates #'mod-dired--treemacs-noise-file-p)
  (add-hook 'treemacs-mode-hook #'mod-dired-setup-treemacs-buffer)
  (treemacs-load-theme "Default")
  (mod-dired-setup-treemacs-icons)
  (mod-dired--configure-treemacs-for-path (or buffer-file-name default-directory)))

(with-eval-after-load 'treemacs-tags
  (advice-add 'treemacs--get-imenu-index :around #'mod-dired--treemacs-safe-imenu-index)
  (advice-add 'treemacs--call-imenu-and-goto-tag :around #'mod-dired--treemacs-call-imenu-fallback)
  (advice-add 'treemacs--goto-tag :around #'mod-dired--treemacs-goto-tag-fallback))

(use-package treemacs-evil
  :ensure t
  :after (treemacs evil))

(provide 'mod-dired)

;;; mod-dired.el ends here
