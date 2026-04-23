;;; mod-core.el --- Core bootstrap -*- lexical-binding: t; -*-

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

(defun mod-core--require-elpaca (repo)
  (let ((load-path (cons repo load-path)))
    (require 'elpaca)))

(dolist (dir (list mod-core-var-directory
                   mod-core-backup-directory
                   mod-core-auto-save-directory
                   mod-core-lockfile-directory))
  (make-directory dir t))

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
    (elpaca elpaca-use-package
      (elpaca-use-package-mode))
    (setq elpaca-use-package-by-default t)))

(provide 'mod-core)

;;; mod-core.el ends here
