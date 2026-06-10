;;; mod-completion.el --- Completion and navigation foundation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(declare-function mod-tcl-docs-completion-entry "mod-tcl-docs" (symbol))

(defun mod-completion-corfu-kind-margin (metadata)
  "Return a Tcl-aware Corfu margin formatter for completion METADATA."
  (when (eq (completion-metadata-get metadata 'category) 'tcl-symbol)
    (lambda (candidate)
      (let* ((entry (and (fboundp 'mod-tcl-docs-completion-entry)
                         (ignore-errors (mod-tcl-docs-completion-entry candidate))))
             (kind (plist-get entry :kind))
             (icon
              (pcase kind
                ("function" (if (char-displayable-p ?λ) "λ " "f "))
                ("namespace" (if (char-displayable-p ?◆) "◆ " "n "))
                ("variable" (if (char-displayable-p ?•) "• " "v "))
                ("file" (if (char-displayable-p ?◌) "◌ " "F "))
                (_ "· "))))
        (propertize icon 'face 'font-lock-keyword-face)))))

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

(defun mod-completion--capf-label (capf)
  "Return a readable label for CAPF."
  (cond
   ((symbolp capf) (symbol-name capf))
   ((byte-code-function-p capf) "#<byte-code capf>")
   ((functionp capf) "#<function capf>")
   (t (format "%S" capf))))

(defun mod-completion--sample-candidates (prefix table)
  "Return a short diagnostic sample for PREFIX in completion TABLE."
  (condition-case err
      (let* ((candidates (all-completions prefix table))
             (sample (seq-take candidates 10)))
        (format "%d candidate%s%s"
                (length candidates)
                (if (= (length candidates) 1) "" "s")
                (if sample
                    (format ": %s" (string-join sample ", "))
                  "")))
    (error
     (format "candidate lookup failed: %s" (error-message-string err)))))

(defun mod-completion-diagnose-at-point ()
  "Display CAPF and Corfu diagnostics for the current buffer."
  (interactive)
  (let* ((source-buffer (current-buffer))
         (source-point (point))
         (capfs completion-at-point-functions)
         (report (get-buffer-create "*Orbit Completion Diagnostics*")))
    (with-current-buffer report
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Buffer: %s\n" (buffer-name source-buffer)))
        (insert (format "Mode: %s\n" (buffer-local-value 'major-mode source-buffer)))
        (insert (format "Point: %d\n\n" source-point))
        (insert (format "global-corfu-mode: %S\n" (bound-and-true-p global-corfu-mode)))
        (insert (format "corfu-mode: %S\n" (buffer-local-value 'corfu-mode source-buffer)))
        (insert (format "corfu-auto: %S\n" (and (boundp 'corfu-auto) corfu-auto)))
        (insert (format "corfu-auto-delay: %S\n" (and (boundp 'corfu-auto-delay) corfu-auto-delay)))
        (insert (format "corfu-auto-prefix: %S\n" (and (boundp 'corfu-auto-prefix) corfu-auto-prefix)))
        (insert (format "corfu-quit-at-boundary: %S\n" (and (boundp 'corfu-quit-at-boundary) corfu-quit-at-boundary)))
        (insert (format "corfu-quit-no-match: %S\n\n" (and (boundp 'corfu-quit-no-match) corfu-quit-no-match)))
        (insert (format "completion-at-point-functions: %d\n\n" (length capfs)))
        (cl-loop for capf in capfs
                 for index from 1
                 do
                 (insert (format "%d. %s\n" index (mod-completion--capf-label capf)))
                 (insert
                  (with-current-buffer source-buffer
                    (save-excursion
                      (goto-char source-point)
                      (condition-case err
                          (let ((result (funcall capf)))
                            (cond
                             ((not result)
                              "   result: nil\n\n")
                             ((and (listp result)
                                   (integer-or-marker-p (nth 0 result))
                                   (integer-or-marker-p (nth 1 result)))
                              (let* ((beg (nth 0 result))
                                     (end (nth 1 result))
                                     (table (nth 2 result))
                                     (props (nthcdr 3 result))
                                     (prefix (buffer-substring-no-properties beg end))
                                     (metadata (completion-metadata prefix table nil)))
                                (concat
                                 (format "   bounds: %d..%d\n" beg end)
                                 (format "   prefix: %S\n" prefix)
                                 (format "   category: %S\n"
                                         (completion-metadata-get metadata 'category))
                                 (format "   props: %S\n" props)
                                 (format "   sample: %s\n\n"
                                         (mod-completion--sample-candidates prefix table)))))
                             (t
                              (format "   result: %S\n\n" result))))
                        (error
                         (format "   error: %s\n\n"
                                 (error-message-string err))))))))
        (goto-char (point-min))
        (special-mode)))
    (display-buffer report)))

(use-package vertico
  :ensure (:wait t)
  :demand t
  :config
  (setq vertico-cycle t)
  (vertico-mode 1))

(use-package orderless
  :ensure (:wait t)
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
  :ensure (:wait t)
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
  :ensure (:wait t)
  :demand t
  :config
  (setq corfu-auto t
        corfu-auto-delay 0.15
        corfu-auto-prefix 2
        corfu-quit-at-boundary 'separator
        corfu-quit-no-match 'separator
        corfu-cycle t
        corfu-preselect 'prompt)
  (add-hook 'corfu-margin-formatters #'mod-completion-corfu-kind-margin)
  (define-key corfu-map (kbd "TAB") nil)
  (define-key corfu-map (kbd "<tab>") nil)
  (define-key corfu-map (kbd "<backtab>") nil)
  (define-key corfu-map (kbd "S-TAB") nil)
  (define-key corfu-map (kbd "C-j") #'corfu-next)
  (define-key corfu-map (kbd "C-k") #'corfu-previous)
  (define-key corfu-map (kbd "RET") #'corfu-insert)
  (global-corfu-mode 1))

(use-package corfu-popupinfo
  :ensure nil
  :after corfu
  :config
  (setq corfu-popupinfo-delay '(0.8 . 0.3)
        corfu-popupinfo-min-width 30
        corfu-popupinfo-max-width 72
        corfu-popupinfo-max-height 12
        corfu-popupinfo-direction '(right left vertical))
  (corfu-popupinfo-mode 1))

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
