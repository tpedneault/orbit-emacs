;;; mod-shell.el --- eat terminal integration -*- lexical-binding: t; -*-

(declare-function mod-utility--display-buffer "mod-utility")
(declare-function mod-core--current-project-root "mod-core")
(declare-function eat "eat")

(defvar mod-shell--buffer-name "*eat*"
  "Default eat buffer name for the utility bay shell.")

(defun mod-shell--program ()
  "Return the shell program to use with eat."
  (or orbit-user-shell
      (if (eq system-type 'windows-nt)
          (or (executable-find "pwsh")
              (executable-find "powershell")
              "powershell")
        (or (getenv "SHELL") "/bin/sh"))))

(use-package eat
  :ensure t
  :defer t
  :config
  (with-eval-after-load 'evil
    ;; C-c C-j enters terminal input mode; C-c C-k returns to Emacs/normal mode.
    (evil-define-key '(normal insert) eat-mode-map
      (kbd "C-c C-j") #'eat-semi-char-mode
      (kbd "C-c C-k") #'eat-emacs-mode)))

(defun mod-shell-open ()
  "Open or switch to the eat shell in the utility bay."
  (interactive)
  (require 'eat)
  (let ((buf (get-buffer mod-shell--buffer-name)))
    (if (and buf (buffer-live-p buf))
        (mod-utility--display-buffer buf)
      (let ((default-directory (or (mod-core--current-project-root)
                                   default-directory)))
        (save-window-excursion
          (eat (mod-shell--program)))
        (when-let* ((b (get-buffer mod-shell--buffer-name)))
          (mod-utility--display-buffer b))))))

(defun mod-shell-new (name)
  "Open a new named eat shell called NAME in the utility bay."
  (interactive "sShell name: ")
  (require 'eat)
  (let* ((buf-name (format "*eat:%s*" name))
         (default-directory (or (mod-core--current-project-root)
                                default-directory)))
    (if-let* ((existing (get-buffer buf-name))
              ((buffer-live-p existing)))
        (mod-utility--display-buffer existing)
      (let ((new-buf
             (save-window-excursion
               (eat (mod-shell--program))
               (rename-buffer buf-name t)
               (current-buffer))))
        (mod-utility--display-buffer new-buf)))))

(provide 'mod-shell)

;;; mod-shell.el ends here
