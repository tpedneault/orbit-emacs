;;; orbit-modeline-layout.el --- Layout assembly -*- lexical-binding: t; -*-

(require 'orbit-modeline-segments)

(defun orbit-modeline-left ()
  "Return the left cluster for the current modeline."
  (orbit-modeline--join
   (list
    (orbit-modeline-brand)
    (orbit-modeline-separator)
    (orbit-modeline--propertize
     (format " %s " (or (orbit-modeline-evil-state-text) "-"))
     (orbit-modeline-evil-state-face))
    (orbit-modeline-separator)
    (orbit-modeline--propertize
     (format " %s " (orbit-modeline-buffer-name))
     (orbit-modeline-face 'orbit-modeline-buffer 'mode-line-inactive))
    (let ((markers (orbit-modeline-buffer-state-markers)))
      (when markers
        (concat
         (orbit-modeline-separator)
         (format " %s " (string-join markers " ")))))
    (when-let* ((borrowed (orbit-modeline-borrowed-marker)))
      (concat (orbit-modeline-separator)
              (orbit-modeline--propertize
               (format " %s " borrowed)
               (orbit-modeline-face 'orbit-modeline-borrowed 'mode-line-inactive)))))
   ""))

(defun orbit-modeline-middle ()
  "Return the middle cluster for the current modeline."
  (let ((parts
         (delq nil
               (list
                (when (orbit-modeline-wide-enough-p 70)
                  (when-let* ((mode (orbit-modeline-major-mode)))
                    (orbit-modeline--propertize
                     mode
                     (orbit-modeline-face 'orbit-modeline-mode 'mode-line-inactive))))
                (when (orbit-modeline-wide-enough-p 90)
                  (when-let* ((branch (orbit-modeline-vc-branch)))
                    (orbit-modeline--propertize
                     branch
                     (orbit-modeline-face 'orbit-modeline-vc 'mode-line-inactive))))
                (when-let* ((slot (orbit-modeline-diagnostics-slot)))
                  (orbit-modeline--propertize
                   slot
                   (orbit-modeline-face 'orbit-modeline-meta 'mode-line-inactive)))))))
    (when parts
      (concat
       (orbit-modeline-separator)
       " "
       (orbit-modeline--join parts (orbit-modeline-separator))
       " "))))

(defun orbit-modeline-right ()
  "Return the right cluster for the current modeline."
  (let ((parts
         (delq nil
               (list
                (orbit-modeline--propertize (orbit-modeline-position)
                                            (orbit-modeline-face 'orbit-modeline-position 'mode-line-inactive))
                (orbit-modeline--propertize (orbit-modeline-percent)
                                            (orbit-modeline-face 'orbit-modeline-position 'mode-line-inactive))
                (when (orbit-modeline-wide-enough-p 120)
                  (when-let* ((encoding (orbit-modeline-encoding-eol)))
                    (orbit-modeline--propertize
                     encoding
                     (orbit-modeline-face 'orbit-modeline-meta 'mode-line-inactive))))
                (when (orbit-modeline-wide-enough-p 105)
                  (when-let* ((battery (orbit-modeline-battery)))
                    (orbit-modeline--propertize
                     battery
                     (orbit-modeline-face 'orbit-modeline-right 'mode-line-inactive))))
                (when (orbit-modeline-wide-enough-p 95)
                  (when-let* ((time (orbit-modeline-time)))
                    (orbit-modeline--propertize
                     time
                     (orbit-modeline-face 'orbit-modeline-right 'mode-line-inactive))))))))
    (when parts
      (concat " " (orbit-modeline--join parts (orbit-modeline-separator)) " "))))

(defun orbit-modeline-format ()
  "Return the complete orbit modeline string."
  (condition-case err
      (let* ((lhs (concat (orbit-modeline-left)
                          (or (orbit-modeline-middle) "")))
             (rhs (or (orbit-modeline-right) ""))
             (rhs-width (string-width rhs))
             (fill (propertize " "
                               'display `(space :align-to (- right ,rhs-width))
                               'face (orbit-modeline-face 'mode-line 'mode-line-inactive))))
        (concat lhs fill rhs))
    (error
     (propertize (format "  %s  [modeline error: %s] "
                         (buffer-name)
                         (error-message-string err))
                 'face 'error))))

(provide 'orbit-modeline-layout)

;;; orbit-modeline-layout.el ends here
