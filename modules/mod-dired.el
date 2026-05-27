;;; mod-dired.el --- Dired and project tree foundation -*- lexical-binding: t; -*-

(require 'dired)
(require 'dired-x)
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
(declare-function treemacs--call-imenu-and-goto-tag "treemacs-tags" (tag-path &optional org?))

(setq delete-by-moving-to-trash t
      dired-dwim-target t
      dired-recursive-copies 'always
      dired-recursive-deletes 'top)

(let ((gls (executable-find "gls"))
      (ls (executable-find "ls")))
  (setq insert-directory-program (or gls ls))
  (setq dired-use-ls-dired (and gls t))
  (setq dired-listing-switches
        (if gls
            "-alh --group-directories-first"
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

(defun mod-dired--treemacs-focus-project ()
  "Focus Treemacs on the current project when possible."
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

(defun mod-dired-project-sidebar-toggle ()
  "Toggle the Treemacs project sidebar."
  (interactive)
  (require 'treemacs)
  (if (eq (treemacs-current-visibility) 'visible)
      (treemacs)
    (if (mod-dired--project-root)
        (mod-dired--treemacs-focus-project)
      (treemacs))))

(add-hook 'dired-mode-hook #'hl-line-mode)
(add-hook 'dired-mode-hook #'auto-revert-mode)

(defun mod-dired-setup-treemacs-buffer ()
  "Make Treemacs denser and quieter than a normal editing buffer."
  (when (fboundp 'display-line-numbers-mode)
    (display-line-numbers-mode -1))
  (setq-local line-spacing nil
              cursor-type nil)
  (when (boundp 'display-line-numbers)
    (setq-local display-line-numbers nil)))

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
      "+" #'dired-create-directory)))

(with-eval-after-load 'evil
  (mod-dired-setup-evil))

(use-package treemacs
  :ensure t
  :defer t
  :init
  (setq treemacs-width 34
        treemacs-position 'left
        treemacs-indentation 1
        treemacs-indentation-string " "
        treemacs-show-hidden-files t
        treemacs-silent-filewatch t
        treemacs-space-between-root-nodes nil
        treemacs-user-mode-line-format nil
        treemacs-collapse-dirs 3
        treemacs-git-mode 'deferred)
  :config
  (treemacs-follow-mode 1)
  (treemacs-filewatch-mode 1)
  (treemacs-fringe-indicator-mode 'always)
  (add-hook 'treemacs-mode-hook #'mod-dired-setup-treemacs-buffer)
  (treemacs-load-theme "Default")
  (mod-dired-setup-treemacs-icons)
  (when (fboundp 'treemacs-hide-gitignored-files-mode)
    (treemacs-hide-gitignored-files-mode 1)))

(with-eval-after-load 'treemacs-tags
  (advice-add 'treemacs--call-imenu-and-goto-tag :around #'mod-dired--treemacs-call-imenu-fallback)
  (advice-add 'treemacs--goto-tag :around #'mod-dired--treemacs-goto-tag-fallback))

(use-package treemacs-evil
  :ensure t
  :after (treemacs evil))

(provide 'mod-dired)

;;; mod-dired.el ends here
