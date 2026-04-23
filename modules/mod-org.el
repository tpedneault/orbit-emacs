;;; mod-org.el --- Org and agenda foundation -*- lexical-binding: t; -*-

(require 'org)
(require 'org-agenda)

(defgroup mod-org nil
  "Minimal Org foundation."
  :group 'applications)

(defcustom mod-org-directory
  (expand-file-name "org/" (getenv "HOME"))
  "Base directory for Org notes and agenda files."
  :type 'directory)

(defcustom mod-org-main-file-name "notes.org"
  "Primary Org notes file name within `mod-org-directory'."
  :type 'string)

(defun mod-org-main-file ()
  "Return the full path to the primary Org notes file."
  (expand-file-name mod-org-main-file-name mod-org-directory))

(defun mod-org--ensure-directory ()
  "Ensure the Org directory exists."
  (make-directory mod-org-directory t))

(defun mod-org-refresh-agenda-files ()
  "Refresh `org-agenda-files' from `mod-org-directory'."
  (mod-org--ensure-directory)
  (setq org-agenda-files
        (or (directory-files-recursively mod-org-directory "\\.org\\'")
            (list (mod-org-main-file)))))

(setq org-directory mod-org-directory
      org-default-notes-file (mod-org-main-file))

(mod-org-refresh-agenda-files)

(defun mod-org-open-notes ()
  "Open the primary Org notes file."
  (interactive)
  (mod-org--ensure-directory)
  (find-file (mod-org-main-file)))

(defun mod-org-open-agenda ()
  "Open the Org agenda."
  (interactive)
  (mod-org-refresh-agenda-files)
  (org-agenda nil "a"))

(provide 'mod-org)

;;; mod-org.el ends here
