;;; early-init.el --- Early startup configuration -*- lexical-binding: t; -*-

;; Avoid package.el startup side effects; Elpaca owns package installation.
(setq package-enable-at-startup nil)

;; Keep startup quiet and lean.
(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil
      frame-inhibit-implied-resize t
      use-dialog-box nil
      ring-bell-function #'ignore)

;; Prefer newer sources when loading Lisp files.
(setq load-prefer-newer t)

;; Reduce UI work before init finishes.
(when (fboundp 'menu-bar-mode)
  (menu-bar-mode -1))
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))

;; Slightly improve startup throughput during initialization.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1)))

;;; early-init.el ends here
