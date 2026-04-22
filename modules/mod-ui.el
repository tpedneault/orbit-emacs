;;; mod-ui.el --- UI foundation -*- lexical-binding: t; -*-

(defconst mod-ui-default-font "IBM Plex Mono"
  "Default fixed-pitch font family for the UI.")

(defconst mod-ui-default-theme 'modus-vivendi
  "Default built-in theme for the UI.")

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

(setq-default display-line-numbers-type 'relative
              indicate-empty-lines t
              cursor-in-non-selected-windows nil)

(global-display-line-numbers-mode 1)
(column-number-mode 1)

;; Skip line numbers where they add noise rather than navigation value.
(dolist (hook '(minibuffer-setup-hook
                term-mode-hook
                shell-mode-hook
                eshell-mode-hook))
  (add-hook hook (lambda () (display-line-numbers-mode -1))))

(provide 'mod-ui)

;;; mod-ui.el ends here
