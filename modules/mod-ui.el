;;; mod-ui.el --- UI foundation -*- lexical-binding: t; -*-

(require 'recentf)
(require 'subr-x)
(require 'whitespace)

(declare-function persp-current-name "perspective")
(declare-function battery "battery")

(defconst mod-ui-default-font "IBM Plex Mono"
  "Default fixed-pitch font family for the UI.")

(defconst mod-ui-default-theme 'modus-vivendi
  "Default built-in theme for the UI.")

(defconst mod-ui-recentf-save-file
  (expand-file-name "recentf" mod-core-var-directory)
  "Path used to persist recentf data.")

(defconst mod-ui-big-font-scale 1.4
  "Multiplier used when enabling big font mode.")

(defconst mod-ui-big-font-weight 'bold
  "Default face weight used when enabling big font mode.")

(defvar-local mod-ui--saved-mode-line-format nil
  "Buffer-local saved modeline used by `mod-ui-toggle-modeline'.")

(defvar-local mod-ui--whitespace-visible nil
  "Buffer-local state used by `mod-ui-toggle-whitespace'.")

(defun mod-ui-font-family ()
  "Return the preferred UI font family."
  (or orbit-user-font-family mod-ui-default-font))

(defun mod-ui-font-height ()
  "Return the preferred UI font height, or nil."
  orbit-user-font-height)

(defun mod-ui-context-name ()
  "Return the current Perspective context name, or nil."
  (when (bound-and-true-p persp-mode)
    (ignore-errors (persp-current-name))))

(defun mod-ui-context-modeline ()
  "Return the current context in bracket form for the modeline."
  (when-let* ((name (mod-ui-context-name)))
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
   (buffer-read-only "RO")
   ((buffer-modified-p) "*")
   (t "")))

(defun mod-ui--segment-string (segment)
  "Return SEGMENT rendered as a plain modeline string, or nil when empty."
  (when segment
    (let ((value (string-trim (format-mode-line segment))))
      (unless (string-empty-p value)
        value))))

(defun mod-ui-buffer-name-modeline ()
  "Return the current buffer name for the modeline."
  (propertize (buffer-name) 'face 'mode-line-buffer-id))

(defun mod-ui-major-mode-modeline ()
  "Return the current major mode name for the modeline."
  (or (mod-ui--segment-string mode-name)
      (and mode-name (format "%s" mode-name))))

(defun mod-ui-vc-branch-modeline ()
  "Return the current Git branch when available."
  (when-let* ((file buffer-file-name)
              (backend (vc-backend file))
              ((eq backend 'Git))
              (raw vc-mode))
    (let ((branch (string-trim (substring-no-properties raw))))
      (setq branch (replace-regexp-in-string "\\`Git[:-]?" "" branch))
      (setq branch (replace-regexp-in-string "\\`[-:[:space:]]+" "" branch))
      (unless (string-empty-p branch)
        branch))))

(defun mod-ui-battery-modeline ()
  "Return a compact battery percentage when available."
  (when (and (boundp 'battery-status-function) battery-status-function)
    (let ((data (ignore-errors (funcall battery-status-function))))
      (when (and data (not (equal "N/A" (battery-format "%B" data))))
        (string-trim (battery-format "%p%%" data))))))

(defun mod-ui-window-width ()
  "Return the width of the selected window."
  (window-total-width (selected-window)))

(defun mod-ui-wide-enough-p (width)
  "Return non-nil when the selected window is at least WIDTH columns wide."
  (>= (mod-ui-window-width) width))

(defun mod-ui-right-segment ()
  "Return the compact right side of the modeline."
  (string-join
   (delq nil
         (list (and (mod-ui-wide-enough-p 100) (mod-ui-vc-branch-modeline))
               (mod-ui--segment-string "%l:%c")
               (and (mod-ui-wide-enough-p 85) (mod-ui-battery-modeline))
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
               (and (mod-ui-wide-enough-p 70) (mod-ui-major-mode-modeline))))
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
      (set-face-attribute 'default frame
                          :family (mod-ui-font-family)
                          :height (or (mod-ui-font-height) 'unspecified)))))

(defun mod-ui--frame-default-height (&optional frame)
  "Return the current default face height for FRAME."
  (let ((height (face-attribute 'default :height (or frame (selected-frame)) 'default)))
    (if (integerp height)
        height
      (or (mod-ui-font-height) 140))))

(defun mod-ui-toggle-fullscreen ()
  "Toggle the selected frame between fullscreen and normal."
  (interactive)
  (set-frame-parameter
   nil
   'fullscreen
   (if (frame-parameter nil 'fullscreen) nil 'fullboth)))

(defun mod-ui-toggle-big-font ()
  "Toggle a larger, bolder default font on the selected frame."
  (interactive)
  (let* ((frame (selected-frame))
         (enabled (frame-parameter frame 'mod-ui-big-font-enabled)))
    (if enabled
        (progn
          (set-face-attribute
           'default frame
           :height (or (frame-parameter frame 'mod-ui-big-font-prev-height) 'unspecified)
           :weight (or (frame-parameter frame 'mod-ui-big-font-prev-weight) 'normal))
          (set-frame-parameter frame 'mod-ui-big-font-enabled nil)
          (set-frame-parameter frame 'mod-ui-big-font-prev-height nil)
          (set-frame-parameter frame 'mod-ui-big-font-prev-weight nil)
          (message "Big font mode disabled"))
      (let ((height (mod-ui--frame-default-height frame))
            (weight (face-attribute 'default :weight frame 'default)))
        (set-frame-parameter frame 'mod-ui-big-font-prev-height height)
        (set-frame-parameter frame 'mod-ui-big-font-prev-weight weight)
        (set-face-attribute
         'default frame
         :height (round (* height mod-ui-big-font-scale))
         :weight mod-ui-big-font-weight)
        (set-frame-parameter frame 'mod-ui-big-font-enabled t)
        (message "Big font mode enabled")))))

(defun mod-ui-toggle-line-numbers ()
  "Toggle line numbers in the current buffer."
  (interactive)
  (if (bound-and-true-p display-line-numbers-mode)
      (progn
        (display-line-numbers-mode -1)
        (message "Line numbers disabled"))
    (display-line-numbers-mode 1)
    (message "Line numbers enabled")))

(defun mod-ui-toggle-line-number-style ()
  "Toggle line numbers between relative and absolute styles."
  (interactive)
  (let ((new-type (if (eq display-line-numbers-type 'relative) t 'relative)))
    (setq-default display-line-numbers-type new-type)
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (bound-and-true-p display-line-numbers-mode)
          (setq-local display-line-numbers new-type)
          (display-line-numbers-mode -1)
          (display-line-numbers-mode 1))))
    (message "Line number style: %s"
             (if (eq new-type 'relative) "relative" "absolute"))))

(defun mod-ui-toggle-hl-line ()
  "Toggle current-line highlighting in the current buffer."
  (interactive)
  (if (bound-and-true-p hl-line-mode)
      (progn
        (hl-line-mode -1)
        (message "Current line highlight disabled"))
    (hl-line-mode 1)
    (message "Current line highlight enabled")))

(defun mod-ui-toggle-whitespace ()
  "Toggle simple whitespace visibility in the current buffer."
  (interactive)
  (setq-local whitespace-style '(face tabs trailing))
  (if (or mod-ui--whitespace-visible
          (bound-and-true-p whitespace-mode))
      (progn
        (setq-local mod-ui--whitespace-visible nil)
        (whitespace-mode -1)
        (message "Whitespace visibility disabled"))
    (setq-local mod-ui--whitespace-visible t)
    (whitespace-mode 1)
    (message "Whitespace visibility enabled")))

(defun mod-ui-toggle-modeline ()
  "Toggle modeline visibility in the current buffer."
  (interactive)
  (if mode-line-format
      (progn
        (setq mod-ui--saved-mode-line-format mode-line-format)
        (setq-local mode-line-format nil)
        (force-mode-line-update)
        (message "Modeline hidden"))
    (setq-local mode-line-format
                (or mod-ui--saved-mode-line-format
                    (default-value 'mode-line-format)))
    (force-mode-line-update)
    (message "Modeline shown")))

(defun mod-ui-toggle-fill-column-indicator ()
  "Toggle the fill-column indicator in the current buffer."
  (interactive)
  (if (bound-and-true-p display-fill-column-indicator-mode)
      (progn
        (display-fill-column-indicator-mode -1)
        (message "Fill-column indicator disabled"))
    (display-fill-column-indicator-mode 1)
    (message "Fill-column indicator enabled")))

(defun mod-ui-apply-truncate-defaults ()
  "Apply the default unwrapped line behavior to the current buffer."
  (setq truncate-lines t
        word-wrap nil))

(defun mod-ui-enable-prog-layout ()
  "Keep programming buffers in truncation mode."
  (mod-ui-apply-truncate-defaults)
  (when (bound-and-true-p visual-line-mode)
    (visual-line-mode -1)))

(defun mod-ui-enable-org-layout ()
  "Keep Org buffers in wrapped reading mode."
  (setq truncate-lines nil
        word-wrap t)
  (visual-line-mode 1))

(defun mod-ui-toggle-wrap ()
  "Toggle the current buffer between wrapped and truncated lines."
  (interactive)
  (if (bound-and-true-p visual-line-mode)
      (progn
        (visual-line-mode -1)
        (mod-ui-apply-truncate-defaults)
        (message "Line wrapping disabled"))
    (setq truncate-lines nil
          word-wrap t)
    (visual-line-mode 1)
    (message "Line wrapping enabled")))

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
              cursor-in-non-selected-windows nil
              truncate-lines t
              word-wrap nil)

(setq recentf-save-file mod-ui-recentf-save-file
      save-place-file mod-core-save-place-file
      recentf-max-saved-items 200
      auto-revert-verbose nil)

(when (bound-and-true-p global-visual-line-mode)
  (global-visual-line-mode -1))

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

(add-hook 'prog-mode-hook #'mod-ui-enable-prog-layout)
(add-hook 'org-mode-hook #'mod-ui-enable-org-layout)

(provide 'mod-ui)

;;; mod-ui.el ends here
