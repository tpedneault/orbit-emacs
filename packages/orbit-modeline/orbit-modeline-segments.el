;;; orbit-modeline-segments.el --- Segment helpers -*- lexical-binding: t; -*-

(require 'subr-x)

(declare-function battery "battery")
(declare-function orbit-context-buffer-borrowed-p "orbit-context" (&optional buffer name))

(defun orbit-modeline-selected-p ()
  "Return non-nil when formatting the selected window's modeline."
  (if (fboundp 'mode-line-window-selected-p)
      (mode-line-window-selected-p)
    t))

(defun orbit-modeline-face (active-face &optional inactive-face)
  "Return ACTIVE-FACE or INACTIVE-FACE depending on modeline selection."
  (if (orbit-modeline-selected-p)
      active-face
    (or inactive-face 'mode-line-inactive)))

(defun orbit-modeline--propertize (text face)
  "Return TEXT propertized with FACE when TEXT is non-empty."
  (when (and text (not (string-empty-p text)))
    (propertize text 'face face)))

(defun orbit-modeline--join (parts &optional separator)
  "Join non-empty PARTS with SEPARATOR."
  (string-join (delq nil parts) (or separator "  ")))

(defun orbit-modeline-window-width ()
  "Return the width of the selected window."
  (window-total-width (selected-window)))

(defun orbit-modeline-wide-enough-p (width)
  "Return non-nil when the selected window is at least WIDTH columns wide."
  (>= (orbit-modeline-window-width) width))

(defun orbit-modeline-evil-state-text ()
  "Return the compact Evil state text."
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

(defun orbit-modeline-evil-state-face ()
  "Return the face for the current Evil state."
  (orbit-modeline-face
   (pcase (and (bound-and-true-p evil-local-mode) evil-state)
     ('normal 'orbit-modeline-evil-normal)
     ('insert 'orbit-modeline-evil-insert)
     ('visual 'orbit-modeline-evil-visual)
     ('replace 'orbit-modeline-evil-replace)
     ('emacs 'orbit-modeline-evil-emacs)
     ('motion 'orbit-modeline-evil-motion)
     (_ 'orbit-modeline-evil-normal))
   'mode-line-inactive))

(defun orbit-modeline-brand ()
  "Return the Orbit brand segment."
  (orbit-modeline--propertize
   " ORBIT "
   (orbit-modeline-face 'orbit-modeline-brand 'mode-line-inactive)))

(defun orbit-modeline-separator ()
  "Return a low-noise Orbit separator."
  (orbit-modeline--propertize
   " · "
   (orbit-modeline-face 'orbit-modeline-separator 'mode-line-inactive)))

(defun orbit-modeline-buffer-name ()
  "Return the current buffer name."
  (buffer-name))

(defun orbit-modeline-buffer-state-markers ()
  "Return a list of buffer state markers."
  (delq nil
        (list
         (when (buffer-modified-p)
           (orbit-modeline--propertize
            "*"
            (orbit-modeline-face 'orbit-modeline-state-modified 'mode-line-inactive)))
         (when buffer-read-only
           (orbit-modeline--propertize
            "RO"
            (orbit-modeline-face 'orbit-modeline-state-read-only 'mode-line-inactive)))
         (when (buffer-narrowed-p)
           (orbit-modeline--propertize
            "NAR"
            (orbit-modeline-face 'orbit-modeline-state-narrowed 'mode-line-inactive))))))

(defun orbit-modeline-borrowed-marker ()
  "Return the borrowed marker for the current buffer, or nil."
  (when (and (fboundp 'orbit-context-buffer-borrowed-p)
             (ignore-errors (orbit-context-buffer-borrowed-p)))
    (orbit-modeline--propertize
     "BOR"
     (orbit-modeline-face 'orbit-modeline-borrowed 'mode-line-inactive))))

(defun orbit-modeline-major-mode ()
  "Return the current major mode name."
  (let ((value (string-trim (format-mode-line mode-name))))
    (unless (string-empty-p value)
      value)))

(defun orbit-modeline-vc-branch ()
  "Return the current VC branch, or nil."
  (when-let* ((raw (and (bound-and-true-p vc-mode)
                        (stringp vc-mode)
                        vc-mode)))
    (let ((branch (string-trim
                   (replace-regexp-in-string "^ Git[:-]?" ""
                                             (substring-no-properties raw)))))
      (unless (string-empty-p branch)
        branch))))

(defun orbit-modeline-diagnostics-slot ()
  "Return an optional diagnostics or LSP segment.
Reserved for future use; intentionally nil for now."
  nil)

(defun orbit-modeline-position ()
  "Return line and column for the current point."
  (format-mode-line "%l:%c"))

(defun orbit-modeline-percent ()
  "Return percent-through-buffer."
  (format-mode-line "%p"))

(defun orbit-modeline--coding-base-name ()
  "Return the base coding system name for the current buffer."
  (when-let* ((coding buffer-file-coding-system)
              (base (coding-system-base coding)))
    (symbol-name base)))

(defun orbit-modeline--eol-name ()
  "Return a compact EOL label for the current buffer."
  (pcase (coding-system-eol-type buffer-file-coding-system)
    (0 "LF")
    (1 "CRLF")
    (2 "CR")
    (_ nil)))

(defun orbit-modeline-encoding-eol ()
  "Return a compact encoding/EOL indicator when non-default."
  (when-let* ((coding buffer-file-coding-system))
    (let* ((base (orbit-modeline--coding-base-name))
           (eol (orbit-modeline--eol-name))
           (show-base (and base (not (string= base "utf-8"))))
           (show-eol (and eol (not (string= eol "LF")))))
      (when (or show-base show-eol)
        (string-join (delq nil (list (and show-base base)
                                     (and show-eol eol)))
                     "/")))))

(defun orbit-modeline-battery ()
  "Return compact battery text, or nil."
  (when (and (boundp 'battery-status-function) battery-status-function)
    (let ((data (ignore-errors (funcall battery-status-function))))
      (when (and data (not (equal "N/A" (battery-format "%B" data))))
        (string-trim (battery-format "%p%%" data))))))

(defun orbit-modeline-time ()
  "Return current time text when `display-time-mode' is active."
  (when (bound-and-true-p display-time-mode)
    (format-time-string "%H:%M")))

(provide 'orbit-modeline-segments)

;;; orbit-modeline-segments.el ends here
