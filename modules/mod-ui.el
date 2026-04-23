;;; mod-ui.el --- UI foundation -*- lexical-binding: t; -*-

(require 'recentf)
(require 'subr-x)

(declare-function persp-current-name "perspective")
(declare-function battery "battery")

(defconst mod-ui-default-font "IBM Plex Mono"
  "Default fixed-pitch font family for the UI.")

(defconst mod-ui-default-theme 'modus-vivendi
  "Default built-in theme for the UI.")

(defconst mod-ui-recentf-save-file
  (expand-file-name "recentf" mod-core-var-directory)
  "Path used to persist recentf data.")

(defun mod-ui-context-name ()
  "Return the current Perspective context name, or nil."
  (when (bound-and-true-p persp-mode)
    (ignore-errors (persp-current-name))))

(defun mod-ui-context-modeline ()
  "Return the current context in bracket form for the modeline."
  (when-let ((name (mod-ui-context-name)))
    (format "[%s]" name)))

(defun mod-ui-evil-state-modeline ()
  "Return a short Evil state indicator for the modeline."
  (when (bound-and-true-p evil-local-mode)
    (pcase evil-state
      ('normal "N")
      ('insert "I")
      ('visual "V")
      ('replace "R")
      ('motion "M")
      ('operator "O")
      ('emacs "E")
      (_ "-"))))

(defun mod-ui-buffer-status-modeline ()
  "Return a compact buffer status indicator."
  (cond
   (buffer-read-only " RO")
   ((buffer-modified-p) " *")
   (t "")))

(defun mod-ui--segment-string (segment)
  "Return SEGMENT rendered as a plain modeline string, or nil when empty."
  (when segment
    (let ((value (string-trim (format-mode-line segment))))
      (unless (string-empty-p value)
        value))))

(defun mod-ui-buffer-name-modeline ()
  "Return the current buffer name for the modeline."
  (buffer-name))

(defun mod-ui-major-mode-modeline ()
  "Return the current major mode name for the modeline."
  (or (mod-ui--segment-string mode-name)
      (and mode-name (format "%s" mode-name))))

(defun mod-ui-vc-branch-modeline ()
  "Return a compact VC branch display when available."
  (when (and vc-mode (stringp vc-mode))
    (let* ((backend (if (boundp 'vc-backend) vc-backend (vc-backend buffer-file-name)))
           (branch (string-trim (substring-no-properties vc-mode))))
      (when (and backend (string-prefix-p " " branch))
        (setq branch (string-trim branch)))
      (when backend
        (format "%s:%s" backend branch)))))

(defun mod-ui-battery-modeline ()
  "Return a compact battery string when available."
  (when (and (boundp 'battery-status-function) battery-status-function)
    (let ((data (ignore-errors (funcall battery-status-function))))
      (when (and data (not (equal "N/A" (battery-format "%B" data))))
        (string-trim (battery-format "%b%p%%" data))))))

(defun mod-ui-right-segment ()
  "Return the compact right side of the modeline."
  (string-join
   (delq nil
         (list (mod-ui-vc-branch-modeline)
               (mod-ui--segment-string "%l:%c")
               (mod-ui-battery-modeline)
               (and (bound-and-true-p display-time-mode) (format-time-string "%H:%M"))))
   "  "))

(defun mod-ui-left-segment ()
  "Return the compact left side of the modeline."
  (string-join
   (delq nil
         (list (mod-ui-evil-state-modeline)
               (mod-ui-context-modeline)
               (mod-ui-buffer-name-modeline)
               (mod-ui-buffer-status-modeline)
               (mod-ui-major-mode-modeline)))
   " "))

(defun mod-ui-apply-frame-defaults (&optional frame)
  "Apply minimal UI defaults to FRAME or the current frame."
  (with-selected-frame (or frame (selected-frame))
    (when (fboundp 'menu-bar-mode)
      (menu-bar-mode -1))
    (when (fboundp 'tool-bar-mode)
      (tool-bar-mode -1))
    (when (fboundp 'scroll-bar-mode)
      (scroll-bar-mode -1))
    (when (display-graphic-p)
      (set-face-attribute 'default frame :family mod-ui-default-font))))

;; Keep new GUI frames aligned with the text-first startup defaults.
(add-to-list 'default-frame-alist '(menu-bar-lines . 0))
(add-to-list 'default-frame-alist '(tool-bar-lines . 0))
(add-to-list 'default-frame-alist '(vertical-scroll-bars))

(add-hook 'after-make-frame-functions #'mod-ui-apply-frame-defaults)
(mod-ui-apply-frame-defaults)

(unless (custom-theme-enabled-p mod-ui-default-theme)
  (load-theme mod-ui-default-theme t))

(setq-default mode-line-format
              '("%e"
                mode-line-front-space
                (:eval
                 (let ((lhs (mod-ui-left-segment))
                       (rhs (mod-ui-right-segment)))
                   (concat
                    lhs
                    " "
                    (propertize " " 'display `(space :align-to (- right ,(string-width rhs))))
                    rhs)))
                mode-line-end-spaces))

(setq-default display-line-numbers-type 'relative
              indicate-empty-lines t
              cursor-in-non-selected-windows nil)

(setq recentf-save-file mod-ui-recentf-save-file
      recentf-max-saved-items 200
      auto-revert-verbose nil)

(global-display-line-numbers-mode 1)
(column-number-mode 1)
(display-time-mode 1)
(winner-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(global-auto-revert-mode 1)
(when (and (boundp 'battery-status-function) battery-status-function)
  (display-battery-mode 1))

;; Skip line numbers where they add noise rather than navigation value.
(dolist (hook '(minibuffer-setup-hook
                term-mode-hook
                shell-mode-hook
                eshell-mode-hook))
  (add-hook hook (lambda () (display-line-numbers-mode -1))))

(provide 'mod-ui)

;;; mod-ui.el ends here
