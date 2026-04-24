;;; mod-pairs.el --- Minimal paired delimiter workflow -*- lexical-binding: t; -*-

(require 'thingatpt)

(defgroup mod-pairs nil
  "Minimal paired-delimiter and region-growth workflow."
  :group 'editing)

(defface mod-pairs-symbol-highlight-face
  '((t :inherit lazy-highlight))
  "Face used for symbol-at-point highlighting."
  :group 'mod-pairs)

(defcustom mod-pairs-symbol-highlight-delay 0.25
  "Idle delay before refreshing symbol-at-point highlighting."
  :type 'number
  :group 'mod-pairs)

(defvar-local mod-pairs--symbol-highlight-overlays nil
  "Active overlays used by `mod-pairs-symbol-highlight-mode'.")

(defvar-local mod-pairs--symbol-highlight-symbol nil
  "Last symbol highlighted by `mod-pairs-symbol-highlight-mode'.")

(defvar-local mod-pairs--symbol-highlight-timer nil
  "Idle timer used by `mod-pairs-symbol-highlight-mode'.")

(defun mod-pairs--clear-symbol-overlays ()
  "Remove symbol-at-point overlays from the current buffer."
  (mapc #'delete-overlay mod-pairs--symbol-highlight-overlays)
  (setq mod-pairs--symbol-highlight-overlays nil))

(defun mod-pairs--symbol-at-point ()
  "Return a practical symbol name at point, or nil."
  (when-let* ((symbol (thing-at-point 'symbol t))
              ((>= (length symbol) 2))
              ((not (string-match-p "\\`[0-9]+\\'" symbol))))
    symbol))

(defun mod-pairs--highlight-symbol-at-point ()
  "Highlight occurrences of the symbol at point in the current buffer."
  (when (and mod-pairs-symbol-highlight-mode
             (derived-mode-p 'prog-mode)
             (not (minibufferp)))
    (let ((symbol (mod-pairs--symbol-at-point)))
      (unless (equal symbol mod-pairs--symbol-highlight-symbol)
        (setq mod-pairs--symbol-highlight-symbol symbol)
        (mod-pairs--clear-symbol-overlays)
        (when symbol
          (save-excursion
            (goto-char (point-min))
            (let ((regexp (concat "\\_<" (regexp-quote symbol) "\\_>")))
              (while (re-search-forward regexp nil t)
                (unless (and (>= (point) (line-beginning-position))
                             (<= (match-beginning 0) (point))
                             (> (point) (match-beginning 0))
                             (<= (point) (match-end 0)))
                  (let ((overlay (make-overlay (match-beginning 0) (match-end 0))))
                    (overlay-put overlay 'face 'mod-pairs-symbol-highlight-face)
                    (push overlay mod-pairs--symbol-highlight-overlays)))))))))))

(defun mod-pairs--schedule-symbol-highlight ()
  "Schedule an idle symbol-at-point highlight refresh."
  (when mod-pairs--symbol-highlight-timer
    (cancel-timer mod-pairs--symbol-highlight-timer))
  (setq mod-pairs--symbol-highlight-timer
        (run-with-idle-timer
         mod-pairs-symbol-highlight-delay
         nil
         (lambda (buffer)
           (when (buffer-live-p buffer)
             (with-current-buffer buffer
               (when mod-pairs-symbol-highlight-mode
                 (mod-pairs--highlight-symbol-at-point)))))
         (current-buffer))))

(define-minor-mode mod-pairs-symbol-highlight-mode
  "Highlight occurrences of the symbol at point after a short idle delay."
  :lighter nil
  (if mod-pairs-symbol-highlight-mode
      (add-hook 'post-command-hook #'mod-pairs--schedule-symbol-highlight nil t)
    (remove-hook 'post-command-hook #'mod-pairs--schedule-symbol-highlight t)
    (when mod-pairs--symbol-highlight-timer
      (cancel-timer mod-pairs--symbol-highlight-timer)
      (setq mod-pairs--symbol-highlight-timer nil))
    (setq mod-pairs--symbol-highlight-symbol nil)
    (mod-pairs--clear-symbol-overlays)))

(use-package smartparens
  :ensure t
  :hook ((prog-mode . smartparens-mode)
         (prog-mode . show-smartparens-mode)
         (org-mode . smartparens-mode)
         (org-mode . show-smartparens-mode))
  :config
  (require 'smartparens-config))

(use-package expand-region
  :ensure t
  :commands (er/expand-region))

(add-hook 'prog-mode-hook #'mod-pairs-symbol-highlight-mode)

(provide 'mod-pairs)

;;; mod-pairs.el ends here
