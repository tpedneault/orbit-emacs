;;; mod-evil.el --- Evil foundation -*- lexical-binding: t; -*-

;; `evil-collection` expects this to be set before Evil loads.
(setq evil-want-integration t
      evil-want-keybinding nil)

(use-package evil
  :ensure t
  :demand t
  :config
  (define-key evil-motion-state-map "j" #'mod-evil-next-line)
  (define-key evil-motion-state-map "k" #'mod-evil-previous-line)
  (evil-mode 1))

(use-package evil-collection
  :ensure t
  :after evil
  :config
  (evil-collection-init))

(use-package evil-surround
  :ensure t
  :after evil
  :config
  (global-evil-surround-mode 1))

(use-package evil-commentary
  :ensure t
  :after evil
  :config
  (evil-commentary-mode 1))

(use-package evil-args
  :ensure t
  :after evil
  :config
  (define-key evil-inner-text-objects-map "a" #'evil-inner-arg)
  (define-key evil-outer-text-objects-map "a" #'evil-outer-arg))

(use-package evil-mc
  :ensure t
  :after evil
  :config
  (global-evil-mc-mode 1))

;; When j/k deposits point inside a folded (invisible overlay) region, jump to
;; the near edge of the fold so the cursor skips it in one press.
;;
;; We use :after advice on evil-next-line / evil-previous-line rather than
;; post-command-hook because Evil's evil-adjust-cursor runs in post-command-hook
;; and can override a goto-char made there.  Advice runs as part of the command
;; itself, so our repositioning is the final position Evil sees when it later
;; runs its own post-command adjustments.
;;
;; hideshow sets 'invisible to the symbol 'hs on its fold overlays; checking
;; (overlay-get o 'invisible) returns a truthy value for those.  overlays-in
;; is used (rather than overlays-at) for the forward direction so that landing
;; on the fold header line — before the overlay actually starts — is also caught.

(defun mod-evil--top-visible-line-p ()
  "Return non-nil when point is on the first visible line of the window."
  (eq (line-beginning-position)
      (save-excursion
        (goto-char (window-start))
        (line-beginning-position))))

(defun mod-evil--bottom-visible-line-p ()
  "Return non-nil when point is on the last visible line of the window."
  (eq (line-beginning-position)
      (save-excursion
        (goto-char (max (point-min) (1- (window-end nil t))))
        (line-beginning-position))))

(defun mod-evil-next-line (count)
  "Move down COUNT lines, or one-line scroll at the bottom edge of the window.
When COUNT is nil and point is already on the last visible line, scroll by a
single line instead of nudging the window by one line."
  (interactive "P")
  (let ((count-value (and count (prefix-numeric-value count))))
    (if (and (null count)
             (not (eobp))
             (mod-evil--bottom-visible-line-p))
        (evil-scroll-down 1)
      (evil-next-line (or count-value 1)))))

(defun mod-evil-previous-line (count)
  "Move up COUNT lines, or one-line scroll at the top edge of the window.
When COUNT is nil and point is already on the first visible line, scroll by a
single line instead of nudging the window by one line."
  (interactive "P")
  (let ((count-value (and count (prefix-numeric-value count))))
    (if (and (null count)
             (not (bobp))
             (mod-evil--top-visible-line-p))
        (evil-scroll-up 1)
      (evil-previous-line (or count-value 1)))))

(defun mod-evil--skip-fold-forward (&rest _)
  "After `evil-next-line', jump past any invisible fold overlay at point.
Uses `overlays-in' over the whole current line rather than `overlays-at'
at point, because when the cursor lands at the start of the fold header
line the overlay begins later on that same line and `overlays-at' misses it."
  (when (evil-normal-state-p)
    (when-let* ((ov (cl-find-if (lambda (o) (overlay-get o 'invisible))
                               (overlays-in (line-beginning-position)
                                            (1+ (line-end-position))))))
      ;; overlay-end is often the \n of the last hidden line; jumping there
      ;; would leave Evil's adjust-cursor to back us one char into the fold.
      ;; Advance one more step when at EOL to land on the next visible line.
      (goto-char (overlay-end ov))
      (when (eolp) (forward-line 1)))))

(defun mod-evil--skip-fold-backward (&rest _)
  "After `evil-previous-line', jump before any invisible fold overlay at point."
  (when (evil-normal-state-p)
    (when-let* ((ov (cl-find-if (lambda (o) (overlay-get o 'invisible))
                               (overlays-at (point)))))
      (goto-char (max (point-min) (1- (overlay-start ov)))))))

(advice-add 'evil-next-line     :after #'mod-evil--skip-fold-forward)
(advice-add 'evil-previous-line :after #'mod-evil--skip-fold-backward)

(provide 'mod-evil)

;;; mod-evil.el ends here
