;;; mod-ui.el --- UI foundation -*- lexical-binding: t; -*-

(require 'recentf)
(require 'orbit-modeline)
(require 'subr-x)
(require 'uniquify)
(require 'whitespace)

(declare-function orbit-context-current-kind "orbit-context" (&optional name))
(declare-function orbit-context-current-name "orbit-context")
(declare-function orbit-context-header-label "orbit-context" (&optional name))
(declare-function battery "battery")
(declare-function mod-theme-apply-font-stack "mod-theme")

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

;;; ─── Header-line data helpers ────────────────────────────────────────────────

(defun mod-ui-context-name ()
  "Return the current orbit context name, or nil."
  (when (fboundp 'orbit-context-current-name)
    (ignore-errors (orbit-context-current-name))))

(defun mod-ui-context-kind ()
  "Return the current orbit context kind, or nil."
  (when (fboundp 'orbit-context-current-kind)
    (ignore-errors (orbit-context-current-kind))))

(defun mod-ui-context-header-label ()
  "Return the current orbit context label for the header line."
  (or (when (fboundp 'orbit-context-header-label)
        (ignore-errors (orbit-context-header-label)))
      (mod-ui-context-name)))

(defun mod-ui-context-header-face ()
  "Return the header-line face to use for the current context kind."
  (pcase (mod-ui-context-kind)
    ('edit-project 'orbit-header-context-edit)
    ('git-project 'orbit-header-context-git)
    ('files-root 'orbit-header-context-files)
    ((or 'notes 'agenda) 'orbit-header-context-notes)
    ((or 'edit-roam 'edit-loose) 'orbit-header-context-roam)
    ('scratch 'orbit-header-context-scratch)
    (_ 'orbit-header-context)))

;;; ─── Header line ──────────────────────────────────────────────────────────────

(defun mod-ui-header-path ()
  "Return the buffer path relative to the project root, or the buffer name."
  (cond
   (buffer-file-name
    (let* ((proj (and (fboundp 'project-current) (project-current)))
           (root (and proj (fboundp 'project-root) (project-root proj))))
      (if root
          (file-relative-name buffer-file-name root)
        (abbreviate-file-name buffer-file-name))))
   ((derived-mode-p 'dired-mode)
    (abbreviate-file-name default-directory))
   (t (buffer-name))))

(defun mod-ui-header-clock-string ()
  "Return the active Org clock string for the header line, or nil."
  (when (and (fboundp 'org-clocking-p)
             (org-clocking-p)
             (boundp 'org-clock-heading)
             (fboundp 'org-clock-get-clocked-time)
             (fboundp 'org-duration-from-minutes))
    (format "⏱ %s  %s"
            org-clock-heading
            (org-duration-from-minutes (org-clock-get-clocked-time)))))

(defun mod-ui-header-line-format ()
  "Return the orbit header line format list for the current buffer."
  (let* ((ctx-label (mod-ui-context-header-label))
         (path      (mod-ui-header-path))
         (clock-str (mod-ui-header-clock-string))
         (lhs       (concat
                     (propertize (concat "  ◉ " (or ctx-label "—"))
                                 'face (mod-ui-context-header-face))
                     (propertize "  ›  " 'face 'orbit-header-sep)
                     (propertize path 'face 'orbit-header-path)))
         (rhs       (when clock-str
                      (propertize (concat "  " clock-str "  ")
                                  'face 'orbit-header-clock)))
         (rhs-width (if rhs (string-width rhs) 0))
         (fill      (propertize " "
                                'display `(space :align-to (- right ,rhs-width))
                                'face 'orbit-header-path)))
    (list lhs fill (or rhs ""))))

(defun mod-ui--enable-header-line ()
  "Enable the orbit global header line in the current buffer."
  (setq-local header-line-format '(:eval (mod-ui-header-line-format))))

;;; ─── Frame defaults ───────────────────────────────────────────────────────────

(defun mod-ui-apply-frame-defaults (&optional frame)
  "Apply minimal UI chrome defaults to FRAME or the current frame.
Hides menu bar, tool bar, and scroll bars.  Font configuration is
handled by `mod-theme-apply-font-stack' in mod-theme.el."
  (with-selected-frame (or frame (selected-frame))
    (when (fboundp 'menu-bar-mode)
      (menu-bar-mode -1))
    (when (fboundp 'tool-bar-mode)
      (tool-bar-mode -1))
    (when (fboundp 'scroll-bar-mode)
      (scroll-bar-mode -1))
    ;; Delegate font configuration to mod-theme.
    (when (fboundp 'mod-theme-apply-font-stack)
      (mod-theme-apply-font-stack frame))))

(defun mod-ui--frame-default-height (&optional frame)
  "Return the current default face height for FRAME."
  (let ((height (face-attribute 'default :height (or frame (selected-frame)) 'default)))
    (if (integerp height)
        height
      (or orbit-user-font-height 140))))

;;; ─── Interactive toggle commands ──────────────────────────────────────────────

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

;;; ─── Initialization ───────────────────────────────────────────────────────────

;; Keep new GUI frames aligned with the text-first startup defaults.
(add-to-list 'default-frame-alist '(menu-bar-lines . 0))
(add-to-list 'default-frame-alist '(tool-bar-lines . 0))
(add-to-list 'default-frame-alist '(vertical-scroll-bars))

(add-hook 'after-make-frame-functions #'mod-ui-apply-frame-defaults)
(mod-ui-apply-frame-defaults)

;; ── Orbit modeline ────────────────────────────────────────────────────────────
(orbit-modeline-install)

;; ── Global header line ────────────────────────────────────────────────────────
(add-hook 'find-file-hook  #'mod-ui--enable-header-line)
(add-hook 'dired-mode-hook #'mod-ui--enable-header-line)
(with-eval-after-load 'magit
  (add-hook 'magit-mode-hook #'mod-ui--enable-header-line))
(with-eval-after-load 'org-agenda
  (add-hook 'org-agenda-mode-hook #'mod-ui--enable-header-line))

;; ── Miscellaneous defaults ────────────────────────────────────────────────────
(setq-default display-line-numbers-type 'relative
              indicate-empty-lines t
              cursor-in-non-selected-windows nil
              truncate-lines t
              word-wrap nil)

(setq uniquify-buffer-name-style 'forward
      uniquify-separator "/"
      uniquify-after-kill-buffer-p t
      uniquify-ignore-buffers-re "^\\*")

(setq recentf-save-file        mod-ui-recentf-save-file
      save-place-file         mod-core-save-place-file
      recentf-max-saved-items 200
      ;; Defer recentf cleanup to an idle timer rather than blocking at startup.
      ;; The default 'mode triggers synchronous file-stat on every recentf path
      ;; the moment recentf-mode is enabled — this freezes on Windows when any
      ;; path points to an unreachable network share / UNC mount.
      recentf-auto-cleanup    60
      ;; Prevent save-place from checking whether each saved file is still
      ;; readable at startup — same network-path freeze vector as recentf.
      save-place-forget-unreadable-files nil
      auto-revert-verbose     nil)

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
(add-hook 'org-mode-hook  #'mod-ui-enable-org-layout)

(provide 'mod-ui)

;;; mod-ui.el ends here
