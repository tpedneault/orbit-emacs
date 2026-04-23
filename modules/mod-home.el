;;; mod-home.el --- Minimal orbit home screen -*- lexical-binding: t; -*-

(require 'cl-lib)

(defconst mod-home-buffer-name "*orbit-home*"
  "Name of the Orbit home buffer.")

(defconst mod-home-buffer-lines
  '("   ____  ____  ____  _ _____"
    "  / __ \\/ __ \\/ __ )(_) ___/"
    " / / / / /_/ / __  / /\\__ \\ "
    "/ /_/ / _, _/ /_/ / /___/ / "
    "\\____/_/ |_/_____/_//____/  "
    ""
    "orbit-emacs"
    "Modal, context-based Emacs for focused work."
    ""
    "Start"
    "  SPC x e  edit context"
    "  SPC x a  agenda context"
    "  SPC x o  notes context"
    "  SPC x s  scratch context"
    "  SPC q l  load session"
    ""
    "Common"
    "  SPC SPC  switch buffer"
    "  SPC .    project file"
    "  SPC /    project search"
    "  SPC o s  shell"
    "  SPC n t  capture inbox task"
    "  SPC n a  agenda dashboard"
    ""
    "Contexts"
    "  One task, one workspace."
    "  Keep agenda stable, open items in notes."
    "  Use utility bay for transient support buffers.")
  "Lines displayed in the Orbit home buffer.")

(defun mod-home--user-buffer-p (buffer)
  "Return non-nil when BUFFER counts as a real user buffer."
  (let ((name (buffer-name buffer)))
    (or (buffer-file-name buffer)
        (and (not (string-prefix-p " " name))
             (not (string-prefix-p "*" name))))))

(defun mod-home--empty-startup-p ()
  "Return non-nil when Emacs started into an otherwise empty state."
  (and (not noninteractive)
       (= (length (window-list nil 'no-minibuffer)) 1)
       (let ((current (window-buffer (selected-window))))
         (member (buffer-name current) '("*scratch*" "*Messages*")))
       (not (cl-some #'mod-home--user-buffer-p (buffer-list)))))

(define-derived-mode mod-home-mode special-mode "Orbit-Home"
  "Major mode for the Orbit home buffer."
  (setq-local cursor-type nil
              mode-line-format nil
              truncate-lines t))

(defun mod-home-open ()
  "Open the Orbit home buffer."
  (interactive)
  (let ((buffer (get-buffer-create mod-home-buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (mapconcat #'identity mod-home-buffer-lines "\n"))
        (goto-char (point-min))
        (mod-home-mode)))
    (switch-to-buffer buffer)))

(defun mod-home-show-on-empty-startup ()
  "Show the Orbit home buffer when startup is otherwise empty."
  (when (mod-home--empty-startup-p)
    (mod-home-open)))

(add-hook 'emacs-startup-hook #'mod-home-show-on-empty-startup)

(provide 'mod-home)

;;; mod-home.el ends here
