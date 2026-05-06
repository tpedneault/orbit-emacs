;;; orbit-context-session.el --- Session bridge -*- lexical-binding: t; -*-

(defun orbit-context-session--sidecar-file (session-file)
  "Return the metadata sidecar file for SESSION-FILE."
  (format "%s.contexts.el" session-file))

(defun orbit-context-session-save (session-file)
  "Save Perspective session state and orbit context metadata to SESSION-FILE."
  (persp-state-save session-file)
  (with-temp-file (orbit-context-session--sidecar-file session-file)
    (let ((print-length nil)
          (print-level nil))
      (prin1 (orbit-context--metadata-alist) (current-buffer)))))

(defun orbit-context-session-load (session-file)
  "Load Perspective session state and orbit context metadata from SESSION-FILE."
  (persp-state-load session-file)
  (let ((sidecar (orbit-context-session--sidecar-file session-file)))
    (when (file-exists-p sidecar)
      (with-temp-buffer
        (insert-file-contents sidecar)
        (goto-char (point-min))
        (orbit-context--restore-metadata (read (current-buffer)))))))

(provide 'orbit-context-session)

;;; orbit-context-session.el ends here
