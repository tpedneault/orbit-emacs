;;; early-init.el --- Early startup configuration -*- lexical-binding: t; -*-

(defconst orbit-startup-config-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Root directory for this orbit-emacs configuration.")

(defconst orbit-startup-var-directory
  (expand-file-name "var/" orbit-startup-config-directory)
  "Directory used for local orbit-emacs runtime files.")

(defconst orbit-startup-log-file
  (expand-file-name "startup.log" orbit-startup-var-directory)
  "Startup trace written during early init.")

(defconst orbit-startup-log-threshold 0.05
  "Minimum elapsed seconds before a load/require is logged.")

(defvar orbit-startup-begin-time (current-time)
  "Timestamp captured at the beginning of early init.")

(defvar orbit-startup--trace-depth 0
  "Current nested depth for startup tracing.")

(defvar orbit-startup--finished nil
  "Non-nil once startup completion has been logged.")

(defun orbit-startup--elapsed-seconds ()
  "Return seconds elapsed since `orbit-startup-begin-time'."
  (float-time (time-subtract (current-time) orbit-startup-begin-time)))

(defun orbit-startup--append-log (format-string &rest args)
  "Append a formatted line to `orbit-startup-log-file'."
  (make-directory orbit-startup-var-directory t)
  (with-temp-buffer
    (insert (apply #'format format-string args) "\n")
    (append-to-file (point-min) (point-max) orbit-startup-log-file)))

(defun orbit-startup--trace-require (orig feature &rest args)
  "Advice ORIG around `require' to log slow FEATURE loads."
  (let ((start (current-time))
        (depth orbit-startup--trace-depth))
    (setq orbit-startup--trace-depth (1+ orbit-startup--trace-depth))
    (unwind-protect
        (prog1 (apply orig feature args)
          (let ((elapsed (float-time (time-subtract (current-time) start))))
            (when (>= elapsed orbit-startup-log-threshold)
              (orbit-startup--append-log
               "%7.3fs %srequire %S (%.3fs)"
               (orbit-startup--elapsed-seconds)
               (make-string (* depth 2) ?\s)
               feature
               elapsed))))
      (setq orbit-startup--trace-depth depth))))

(defun orbit-startup--trace-load (orig file &rest args)
  "Advice ORIG around `load' to log slow FILE loads."
  (let ((start (current-time))
        (depth orbit-startup--trace-depth))
    (setq orbit-startup--trace-depth (1+ orbit-startup--trace-depth))
    (unwind-protect
        (prog1 (apply orig file args)
          (let ((elapsed (float-time (time-subtract (current-time) start))))
            (when (>= elapsed orbit-startup-log-threshold)
              (orbit-startup--append-log
               "%7.3fs %sload %S (%.3fs)"
               (orbit-startup--elapsed-seconds)
               (make-string (* depth 2) ?\s)
               file
               elapsed))))
      (setq orbit-startup--trace-depth depth))))

(defun orbit-startup--finish ()
  "Record startup completion exactly once."
  (unless orbit-startup--finished
    (setq orbit-startup--finished t)
    (orbit-startup--append-log
     "%7.3fs startup complete gcs=%s"
     (orbit-startup--elapsed-seconds)
     gcs-done)
    (advice-remove 'require #'orbit-startup--trace-require)
    (advice-remove 'load #'orbit-startup--trace-load)))

(make-directory orbit-startup-var-directory t)
(when (file-exists-p orbit-startup-log-file)
  (delete-file orbit-startup-log-file))
(orbit-startup--append-log
 "%7.3fs startup begin emacs=%s system=%s"
 (orbit-startup--elapsed-seconds)
 emacs-version
 system-type)
(advice-add 'require :around #'orbit-startup--trace-require)
(advice-add 'load :around #'orbit-startup--trace-load)

;; Avoid package.el startup side effects during early init.
;; orbit-emacs initializes packages explicitly from `init.el`.
(setq package-enable-at-startup nil)

;; Emacs 31's native compiler can emit a lot of benign warnings for third-party
;; packages during install/update.  Keep real init errors visible, but suppress
;; this noisy warning class so first-run package setup stays readable.
(add-to-list 'warning-suppress-types '(native-compiler))

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

(add-hook 'after-init-hook #'orbit-startup--finish)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1)
            (orbit-startup--finish)))

;;; early-init.el ends here
