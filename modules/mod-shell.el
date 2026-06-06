;;; mod-shell.el --- vterm terminal integration -*- lexical-binding: t; -*-

(declare-function mod-utility--display-buffer "mod-utility")
(declare-function mod-core--current-project-root "mod-core")
(declare-function vterm "vterm")
(declare-function vterm-copy-mode "vterm")
(defvar vterm-buffer-name)
(defvar vterm-shell)
(defvar vterm-mode-map)
(defvar vterm-always-compile-module)

(defvar mod-shell--buffer-name "*vterm*"
  "Default vterm buffer name for the utility bay shell.")

(defun mod-shell--program ()
  "Return the shell program to use with vterm."
  (or orbit-user-shell
      (or (getenv "SHELL") "/bin/bash" "/bin/sh")))

(use-package vterm
  :ensure nil
  :defer t
  :init
  (setq vterm-always-compile-module t)
  :config
  (define-key vterm-mode-map (kbd "C-c C-k") #'vterm-copy-mode)
  (with-eval-after-load 'evil
    (evil-define-key '(normal insert) vterm-mode-map
      (kbd "C-c C-k") #'vterm-copy-mode)))

(defun mod-shell-open ()
  "Open or switch to the vterm shell in the utility bay."
  (interactive)
  (require 'vterm)
  (let ((buf (get-buffer mod-shell--buffer-name)))
    (if (and buf (buffer-live-p buf))
        (mod-utility--display-buffer buf)
      (let ((default-directory (or (mod-core--current-project-root)
                                   default-directory))
            (vterm-buffer-name mod-shell--buffer-name)
            (vterm-shell (mod-shell--program)))
        (save-window-excursion
          (vterm mod-shell--buffer-name))
        (when-let* ((b (get-buffer mod-shell--buffer-name)))
          (mod-utility--display-buffer b))))))

(defun mod-shell-new (name)
  "Open a new named vterm shell called NAME in the utility bay."
  (interactive "sShell name: ")
  (require 'vterm)
  (let* ((buf-name (format "*vterm:%s*" name))
         (default-directory (or (mod-core--current-project-root)
                                default-directory))
         (vterm-buffer-name buf-name)
         (vterm-shell (mod-shell--program)))
    (if-let* ((existing (get-buffer buf-name))
              ((buffer-live-p existing)))
        (mod-utility--display-buffer existing)
      (let ((new-buf
             (save-window-excursion
               (vterm buf-name)
               (current-buffer))))
        (mod-utility--display-buffer new-buf)))))

(provide 'mod-shell)

;;; mod-shell.el ends here
