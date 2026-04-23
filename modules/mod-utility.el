;;; mod-utility.el --- Utility bay foundation -*- lexical-binding: t; -*-

(defconst mod-utility-window-side 'bottom
  "Side used for the utility bay window.")

(defconst mod-utility-window-slot 0
  "Slot used for the utility bay window.")

(defconst mod-utility-window-height 0.22
  "Default height of the utility bay window.")

(defvar mod-utility-last-buffer nil
  "Most recent buffer shown in the utility bay.")

(defun mod-utility--window ()
  "Return the live utility bay window, if any."
  (get-window-with-predicate
   (lambda (window)
     (window-parameter window 'mod-utility))))

(defun mod-utility--display-buffer (buffer)
  "Display BUFFER in the reusable utility bay window and select it."
  (let ((window
         (display-buffer-in-side-window
          buffer
          `((side . ,mod-utility-window-side)
            (slot . ,mod-utility-window-slot)
            (window-height . ,mod-utility-window-height)))))
    (set-window-parameter window 'mod-utility t)
    (set-window-dedicated-p window nil)
    (setq mod-utility-last-buffer (window-buffer window))
    (select-window window)
    window))

(defun mod-utility-toggle ()
  "Toggle the bottom utility bay window."
  (interactive)
  (if-let ((window (mod-utility--window)))
      (delete-window window)
    (if-let ((buffer (and (buffer-live-p mod-utility-last-buffer)
                          mod-utility-last-buffer)))
        (mod-utility--display-buffer buffer)
      (mod-utility-shell))))

(defun mod-utility-shell ()
  "Open or reuse a shell in the utility bay."
  (interactive)
  (mod-utility--display-buffer
   (or (get-buffer "*shell*")
       (save-window-excursion
         (shell)
         (current-buffer)))))

(defun mod-utility-messages ()
  "Show the *Messages* buffer in the utility bay."
  (interactive)
  (mod-utility--display-buffer (messages-buffer)))

(defun mod-utility-help ()
  "Show a help buffer in the utility bay."
  (interactive)
  (let ((buffer (or (get-buffer "*Help*")
                    (get-buffer "*Apropos*"))))
    (unless buffer
      (user-error "No help buffer available"))
    (mod-utility--display-buffer buffer)))

(defun mod-utility-compilation ()
  "Show the compilation buffer in the utility bay."
  (interactive)
  (let ((buffer (get-buffer "*compilation*")))
    (unless buffer
      (user-error "No compilation buffer available"))
    (mod-utility--display-buffer buffer)))

(provide 'mod-utility)

;;; mod-utility.el ends here
