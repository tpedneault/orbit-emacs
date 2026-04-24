;;; mod-completion.el --- Completion and navigation foundation -*- lexical-binding: t; -*-

(require 'cl-lib)

(defun mod-completion--path-fragment-bounds ()
  "Return bounds for the current non-whitespace fragment ending at point."
  (save-excursion
    (let ((end (point)))
      (skip-chars-backward "^ \t\n\"'`()[]{}<>")
      (cons (point) end))))

(defun mod-completion--path-fragment-at-point ()
  "Return the current non-whitespace fragment ending at point."
  (pcase-let ((`(,beg . ,end) (mod-completion--path-fragment-bounds)))
    (buffer-substring-no-properties beg end)))

(defun mod-completion--path-prefix-p ()
  "Return non-nil when point looks like a file path completion site."
  (let ((fragment (mod-completion--path-fragment-at-point)))
    (string-match-p
     "\\`\\(?:~/[^[:space:]]*\\|\\./[^[:space:]]*\\|\\.\\./[^[:space:]]*\\|/[^[:space:]]*\\|[^[:space:]/][^[:space:]]*/[^[:space:]]*\\)\\'"
     fragment)))

(defun mod-completion--path-components (fragment)
  "Return directory prefix and basename prefix parsed from FRAGMENT."
  (list :directory-prefix (or (file-name-directory fragment) "")
        :basename-prefix (file-name-nondirectory fragment)))

(defun mod-completion--path-candidates (directory-prefix)
  "Return completion candidates found under DIRECTORY-PREFIX."
  (let* ((expanded-directory
          (condition-case nil
              (expand-file-name (substitute-in-file-name directory-prefix))
            (error nil))))
    (when (and expanded-directory
               (file-directory-p expanded-directory))
      (sort
       (cl-loop for entry in (directory-files expanded-directory nil nil t)
                unless (member entry '("." ".."))
                collect (if (file-directory-p (expand-file-name entry expanded-directory))
                            (concat entry "/")
                          entry))
       #'string-lessp))))

(defun mod-completion-file-capf ()
  "Complete file paths conservatively while preserving the typed directory prefix."
  (when (mod-completion--path-prefix-p)
    (let* ((fragment (mod-completion--path-fragment-at-point))
           (components (mod-completion--path-components fragment))
           (directory-prefix (plist-get components :directory-prefix))
           (basename-prefix (plist-get components :basename-prefix))
           (candidates (mod-completion--path-candidates directory-prefix)))
      (when candidates
        (list (- (point) (length basename-prefix))
              (point)
              candidates
              :exclusive 'no
              :company-prefix-length t
              :category 'file
              :annotation-function
              (lambda (candidate)
                (if (string-suffix-p "/" candidate)
                    " Dir"
                  " File")))))))

(use-package vertico
  :ensure t
  :demand t
  :config
  (setq vertico-cycle t)
  (vertico-mode 1))

(use-package orderless
  :ensure t
  :demand t
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :ensure t
  :after vertico
  :config
  (marginalia-mode 1))

(use-package consult
  :ensure t
  :demand t
  :config
  ;; Keep the existing leader tree and upgrade the underlying buffer switcher.
  (global-set-key [remap switch-to-buffer] #'consult-buffer)
  (setq consult-preview-key nil)
  (when orbit-user-rg-program
    (setq consult-ripgrep-args
          (concat
           (shell-quote-argument orbit-user-rg-program)
           " --null --line-buffered --color=never --max-columns=1000"
           " --path-separator / --smart-case --no-heading --line-number ."))))

(use-package corfu
  :ensure t
  :demand t
  :config
  (setq corfu-auto t
        corfu-auto-delay 0.15
        corfu-auto-prefix 2
        corfu-cycle t
        corfu-preselect 'prompt)
  (define-key corfu-map (kbd "TAB") nil)
  (define-key corfu-map (kbd "<tab>") nil)
  (define-key corfu-map (kbd "<backtab>") nil)
  (define-key corfu-map (kbd "S-TAB") nil)
  (define-key corfu-map (kbd "C-j") #'corfu-next)
  (define-key corfu-map (kbd "C-k") #'corfu-previous)
  (define-key corfu-map (kbd "RET") #'corfu-insert)
  (global-corfu-mode 1))

(use-package cape
  :ensure t
  :after corfu
  :config
  (setq-default completion-at-point-functions
                (cl-remove-duplicates
                 (append completion-at-point-functions
                         (list #'mod-completion-file-capf)))))

(savehist-mode 1)

(provide 'mod-completion)

;;; mod-completion.el ends here
