;;; mod-evil.el --- Evil foundation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'color)

;; `evil-collection` expects this to be set before Evil loads.
(setq evil-want-integration t
      evil-want-keybinding nil)

(declare-function evil-get-marker "evil-common" (char &optional raw))
(declare-function evil-mc-has-cursors-p "evil-mc-vars")
(declare-function evil-mc-make-and-goto-next-match "evil-mc-cursor-make")
(declare-function evil-mc-undo-all-cursors "evil-mc-cursor-make")

(defface mod-evil-pulse
  '((t (:inherit secondary-selection)))
  "Face used for brief editing feedback pulses.")

(defconst mod-evil--pulse-face 'mod-evil-pulse
  "Face used for brief editing feedback pulses.")

(defconst mod-evil--pulse-default-interval 0.04
  "Default seconds between editing feedback pulse animation frames.")

(defconst mod-evil--pulse-default-alphas '(0.82 0.62 0.44 0.28 0.15 0.06)
  "Default blend strengths used for editing feedback pulse animation.")

(defun mod-evil--pulse-enabled-p ()
  "Return non-nil when Evil yank/paste pulse feedback is enabled."
  (not (and (boundp 'orbit-user-evil-pulse-enabled)
            (eq orbit-user-evil-pulse-enabled nil))))

(defun mod-evil--pulse-interval ()
  "Return the configured Evil pulse animation interval."
  (if (and (boundp 'orbit-user-evil-pulse-interval)
           (numberp orbit-user-evil-pulse-interval)
           (> orbit-user-evil-pulse-interval 0))
      orbit-user-evil-pulse-interval
    mod-evil--pulse-default-interval))

(defun mod-evil--pulse-alphas ()
  "Return configured Evil pulse blend strengths."
  (let ((alphas (and (boundp 'orbit-user-evil-pulse-alphas)
                     (listp orbit-user-evil-pulse-alphas)
                     (cl-remove-if-not
                      (lambda (alpha)
                        (and (numberp alpha) (<= 0 alpha) (<= alpha 1)))
                      orbit-user-evil-pulse-alphas))))
    (or alphas mod-evil--pulse-default-alphas)))

(defun mod-evil--color-rgb (color)
  "Return COLOR as normalized RGB components, or nil."
  (cond
   ((and (stringp color)
         (string-match
          "\\`#\\([[:xdigit:]]\\{2\\}\\)\\([[:xdigit:]]\\{2\\}\\)\\([[:xdigit:]]\\{2\\}\\)\\'"
          color))
    (mapcar (lambda (group)
              (/ (string-to-number (match-string group color) 16) 255.0))
            '(1 2 3)))
   ((and (stringp color)
         (string-match
          "\\`#\\([[:xdigit:]]\\)\\([[:xdigit:]]\\)\\([[:xdigit:]]\\)\\'"
          color))
    (mapcar (lambda (group)
              (/ (string-to-number (concat (match-string group color)
                                           (match-string group color))
                                   16)
                 255.0))
            '(1 2 3)))
   (t
    (when-let* ((values (and color (color-values color))))
      (mapcar (lambda (value) (/ value 65535.0)) values)))))

(defun mod-evil--pulse-background-color ()
  "Return the current frame background color for pulse blending."
  (or (and (mod-evil--color-rgb (face-background 'default nil t))
           (face-background 'default nil t))
      (and (mod-evil--color-rgb (frame-parameter nil 'background-color))
           (frame-parameter nil 'background-color))
      "#000000"))

(defun mod-evil--pulse-color (alpha)
  "Return a theme-aware pulse color blended by ALPHA."
  (let* ((background (mod-evil--pulse-background-color))
         (accent (or (and (boundp 'orbit-user-evil-pulse-color)
                          orbit-user-evil-pulse-color)
                     (face-background mod-evil--pulse-face nil t)
                     (face-foreground 'warning nil t)
                     (face-background 'region nil t)
                     "#f5d76e"))
         (bg-rgb (mod-evil--color-rgb background))
         (accent-rgb (mod-evil--color-rgb accent)))
    (if (and bg-rgb accent-rgb)
        (apply #'color-rgb-to-hex
               (append
                (cl-mapcar
                 (lambda (from to)
                   (+ (* alpha from) (* (- 1 alpha) to)))
                 accent-rgb bg-rgb)
                '(2)))
      accent)))

(defun mod-evil--pulse-faces ()
  "Return face specs for one editing feedback pulse animation."
  (mapcar
   (lambda (alpha)
     `(:background ,(mod-evil--pulse-color alpha) :extend t))
   (mod-evil--pulse-alphas)))

(defun mod-evil--animate-pulse-overlay (overlay)
  "Animate OVERLAY as a short theme-aware pulse."
  (let ((faces (mod-evil--pulse-faces)))
    (when faces
      (overlay-put overlay 'face (car faces))
      (cl-loop
       for face in (cdr faces)
       for step from 1
       do (run-at-time
           (* (mod-evil--pulse-interval) step)
           nil
           (lambda (overlay face)
             (when (overlay-buffer overlay)
               (overlay-put overlay 'face face)))
           overlay face)))
    (run-at-time
     (* (mod-evil--pulse-interval) (length faces))
     nil #'delete-overlay overlay)))

(defun mod-evil--pulse-region-later (beg end)
  "Briefly highlight BEG to END after the current command finishes."
  (when (and (mod-evil--pulse-enabled-p) beg end (< beg end))
    (let ((buffer (current-buffer))
          (beg-marker (copy-marker beg))
          (end-marker (copy-marker end)))
      (run-at-time
       0 nil
       (lambda (buffer beg-marker end-marker)
         (unwind-protect
             (when (buffer-live-p buffer)
               (with-current-buffer buffer
                 (let ((beg (marker-position beg-marker))
                       (end (marker-position end-marker)))
                   (when (and beg end (< beg end))
                     (let ((overlay (make-overlay beg end nil t t)))
                       (overlay-put overlay 'face mod-evil--pulse-face)
                       (overlay-put overlay 'priority 1000)
                       (overlay-put overlay 'evaporate t)
                       (mod-evil--animate-pulse-overlay overlay))))))
           (set-marker beg-marker nil)
           (set-marker end-marker nil)))
       buffer beg-marker end-marker))))

(defun mod-evil--pulse-yank (&rest args)
  "Pulse the range captured by an Evil yank command."
  (let ((beg (nth 0 args))
        (end (nth 1 args)))
    (mod-evil--pulse-region-later beg end)))

(defun mod-evil--pulse-paste (&rest _)
  "Pulse the range inserted by an Evil paste command."
  (let ((beg (evil-get-marker ?\[))
        (end (evil-get-marker ?\])))
    (when (and beg end)
      (mod-evil--pulse-region-later beg (min (point-max) (1+ end))))))

(defun mod-evil--mc-target-available-p ()
  "Return non-nil when a VS Code-style next-match action makes sense."
  (or (and (fboundp 'evil-mc-has-cursors-p)
           (evil-mc-has-cursors-p))
      (and (bound-and-true-p evil-local-mode)
           (evil-visual-state-p))
      (thing-at-point 'symbol t)))

(defun mod-evil--mc-activate-symbol-selection ()
  "Promote the symbol at point into a visual selection for evil-mc.
This makes the whole symbol visibly selected, which feels much closer to a
VS Code-style Ctrl-D flow than starting from a bare cursor column."
  (unless (evil-visual-state-p)
    (when-let* ((range (ignore-errors (evil-inner-symbol))))
      (evil-visual-char (car range) (1- (cadr range))))))

(defun mod-evil-multicursor-next-match-or-scroll ()
  "Add/select the next match like VS Code `C-d`, or keep scroll fallback.
When there is an active visual selection, an existing evil-mc session, or a
symbol at point, extend the multiple-cursor selection to the next match.
Otherwise preserve Evil's normal half-page scroll on `C-d'."
  (interactive)
  (if (mod-evil--mc-target-available-p)
      (condition-case nil
          (progn
            (mod-evil--mc-activate-symbol-selection)
            (evil-mc-make-and-goto-next-match))
        (error (evil-scroll-down nil)))
    (evil-scroll-down nil)))

(defun mod-evil-multicursor-quit-dwim ()
  "Quit an active evil-mc session, or fall back to the usual quit behavior."
  (interactive)
  (if (and (fboundp 'evil-mc-has-cursors-p)
           (evil-mc-has-cursors-p))
      (evil-mc-undo-all-cursors)
    (keyboard-quit)))

(defun mod-evil--visible-char-before-visual-char (&rest _)
  "Start charwise Visual state on the visible character at end of line."
  (when (and (not (evil-visual-state-p))
             (eolp)
             (not (bolp)))
    (backward-char)))

(use-package evil
  :ensure (:wait t)
  :demand t
  :init
  (setq evil-want-visual-char-semi-exclusive nil)
  :config
  (advice-add 'evil-visual-char :before #'mod-evil--visible-char-before-visual-char)
  (advice-add 'evil-yank :after #'mod-evil--pulse-yank)
  (advice-add 'evil-paste-before :after #'mod-evil--pulse-paste)
  (advice-add 'evil-paste-after :after #'mod-evil--pulse-paste)
  (define-key evil-motion-state-map "j" #'mod-evil-next-line)
  (define-key evil-motion-state-map "k" #'mod-evil-previous-line)
  (evil-set-command-property 'mod-evil-next-line :keep-visual t)
  (evil-set-command-property 'mod-evil-next-line :repeat 'motion)
  (evil-set-command-property 'mod-evil-next-line :type 'line)
  (evil-set-command-property 'mod-evil-previous-line :keep-visual t)
  (evil-set-command-property 'mod-evil-previous-line :repeat 'motion)
  (evil-set-command-property 'mod-evil-previous-line :type 'line)
  (define-key evil-normal-state-map (kbd "C-d") #'mod-evil-multicursor-next-match-or-scroll)
  (define-key evil-visual-state-map (kbd "C-d") #'mod-evil-multicursor-next-match-or-scroll)
  (define-key evil-normal-state-map (kbd "q") #'mod-evil-multicursor-quit-dwim)
  (define-key evil-visual-state-map (kbd "q") #'mod-evil-multicursor-quit-dwim)
  (define-key evil-normal-state-map (kbd "C-g") #'mod-evil-multicursor-quit-dwim)
  (define-key evil-visual-state-map (kbd "C-g") #'mod-evil-multicursor-quit-dwim)
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
