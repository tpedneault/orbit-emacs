;;; mod-snippets.el --- Minimal snippet workflow foundation -*- lexical-binding: t; -*-

(require 'cl-lib)

(declare-function cape-capf-super "cape")

(defconst mod-snippets-directory
  (expand-file-name
   "snippets/"
   (file-name-directory
    (directory-file-name
     (file-name-directory (or load-file-name buffer-file-name)))))
  "Project-local snippet directory.")

(defun mod-snippets-user-directory ()
  "Return the configured user snippet directory."
  (or orbit-user-snippets-directory
      mod-core-user-snippets-directory))

(make-directory mod-snippets-directory t)
(make-directory (mod-snippets-user-directory) t)

(defvar mod-snippets--evil-insert-tab-fallback #'indent-for-tab-command
  "Fallback command for `TAB' in Evil insert state.")

(defvar mod-snippets--evil-insert-backtab-fallback nil
  "Fallback command for `<backtab>' in Evil insert state.")

(defun mod-snippets--bounds ()
  "Return practical snippet completion bounds at point."
  (or (bounds-of-thing-at-point 'symbol)
      (cons (point) (point))))

(defun mod-snippets--templates-for-key (key)
  "Return active Yasnippet templates for KEY."
  (cl-mapcan (lambda (table)
               (yas--fetch table key))
             (yas--get-snippet-tables)))

(defun mod-snippets-completion-at-point ()
  "Provide snippet trigger completion at point for Corfu/CAPF."
  (when (and (bound-and-true-p yas-minor-mode)
             (not (active-minibuffer-window)))
    (pcase-let ((`(,beg . ,end) (mod-snippets--bounds)))
      (when (< beg end)
        (let ((keys (yas-active-keys)))
          (when keys
            (list beg end keys
                  :annotation-function
                  (lambda (candidate)
                    (when-let* ((template (cdar (mod-snippets--templates-for-key candidate))))
                      (format " %s" (yas--template-name template))))
                  :exclusive 'no
                  :exit-function
                  (lambda (_candidate status)
                    (when (eq status 'finished)
                      (yas-expand-from-trigger-key))))))))))

(defun mod-snippets--expand-capfs (capfs)
  "Expand CAPFS, resolving the special symbol `t'."
  (cl-mapcan
   (lambda (fn)
     (cond
      ((eq fn t) (copy-sequence (default-value 'completion-at-point-functions)))
      ((functionp fn) (list fn))
      (t nil)))
   capfs))

(defun mod-snippets-setup-completion ()
  "Integrate Yasnippet completion into the current buffer's CAPF flow."
  (when (bound-and-true-p yas-minor-mode)
    (let* ((base-capfs
            (cl-remove-duplicates
             (cl-remove-if
              (lambda (fn)
                (memq fn '(mod-snippets-completion-at-point mod-snippets--combined-capf)))
              (mod-snippets--expand-capfs completion-at-point-functions))))
           (combined
            (if (and (fboundp 'cape-capf-super) base-capfs)
                (apply #'cape-capf-super
                       (append base-capfs (list #'mod-snippets-completion-at-point)))
              #'mod-snippets-completion-at-point)))
      (setq-local completion-at-point-functions (list combined)))))

(defun mod-snippets-expand-or-tab ()
  "Expand a snippet at point, or fall back to normal `TAB' behavior."
  (interactive)
  (cond
   ((and (bound-and-true-p yas-minor-mode)
         (fboundp 'yas-active-snippets)
         (yas-active-snippets)
         (fboundp 'yas-next-field-or-maybe-expand))
    (call-interactively #'yas-next-field-or-maybe-expand))
   ((and (bound-and-true-p yas-minor-mode)
         (yas-expand)))
   (t
    (call-interactively mod-snippets--evil-insert-tab-fallback))))

(defun mod-snippets-previous-field-or-backtab ()
  "Move to the previous active snippet field, or fall back to `<backtab>'."
  (interactive)
  (cond
   ((and (bound-and-true-p yas-minor-mode)
         (fboundp 'yas-active-snippets)
         (yas-active-snippets)
         (fboundp 'yas-prev-field))
   (call-interactively #'yas-prev-field))
   ((commandp mod-snippets--evil-insert-backtab-fallback)
    (call-interactively mod-snippets--evil-insert-backtab-fallback))))

(use-package yasnippet
  :ensure t
  :demand t
  :config
  (add-to-list 'yas-snippet-dirs (mod-snippets-user-directory))
  (add-to-list 'yas-snippet-dirs mod-snippets-directory)
  (yas-global-mode 0)
  (yas-reload-all)
  (dolist (hook '(prog-mode-hook org-mode-hook))
    (add-hook hook #'yas-minor-mode))
  (add-hook 'yas-minor-mode-hook #'mod-snippets-setup-completion))

(with-eval-after-load 'evil
  (let ((fallback (lookup-key evil-insert-state-map (kbd "TAB"))))
    (when (commandp fallback)
      (setq mod-snippets--evil-insert-tab-fallback fallback)))
  (let ((backtab-fallback (lookup-key evil-insert-state-map (kbd "<backtab>"))))
    (when (commandp backtab-fallback)
      (setq mod-snippets--evil-insert-backtab-fallback backtab-fallback)))
  (define-key evil-insert-state-map (kbd "TAB") #'mod-snippets-expand-or-tab)
  (define-key evil-insert-state-map (kbd "<tab>") #'mod-snippets-expand-or-tab)
  (define-key evil-insert-state-map (kbd "<backtab>") #'mod-snippets-previous-field-or-backtab))

(with-eval-after-load 'yasnippet
  (define-key yas-keymap (kbd "TAB") #'yas-next-field-or-maybe-expand)
  (define-key yas-keymap (kbd "<tab>") #'yas-next-field-or-maybe-expand)
  (define-key yas-keymap (kbd "<backtab>") #'yas-prev-field))

(provide 'mod-snippets)

;;; mod-snippets.el ends here
