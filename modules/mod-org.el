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

(defconst mod-org-default-files
  '("inbox.org" "tasks.org" "projects.org" "notes.org" "journal.org")
  "Default Org files expected under `mod-org-directory'.")

(defconst mod-org-agenda-work-view-key "w"
  "Custom agenda command key for the main work view.")

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

(defun mod-org--agenda-skip-scheduled-or-deadline ()
  "Skip entries which are scheduled or have a deadline."
  (when (or (org-get-scheduled-time (point))
            (org-get-deadline-time (point)))
    (or (outline-next-heading)
        (point-max))))

(setq org-directory mod-org-directory
      org-default-notes-file (mod-org-main-file)
      org-log-into-drawer "LOGBOOK"
      org-log-done 'time
      org-todo-keywords
      '((sequence
         "TODO(t!)"
         "NEXT(n!)"
         "IN-PROGRESS(i!)"
         "WAIT(w@)"
         "|"
         "DONE(d!)"
         "CANCELLED(c!)"))
      org-agenda-custom-commands
      `((,mod-org-agenda-work-view-key "Work"
         ((agenda ""
                  ((org-agenda-span 1)
                   (org-agenda-overriding-header "Schedule")))
          (todo "NEXT|IN-PROGRESS"
                ((org-agenda-overriding-header "Active")))
          (todo "TODO"
                ((org-agenda-overriding-header "Unscheduled TODOs")
                 (org-agenda-skip-function #'mod-org--agenda-skip-scheduled-or-deadline)))))))

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
  (org-agenda nil mod-org-agenda-work-view-key))

(defun mod-org-agenda--marker-at-point ()
  "Return the agenda marker at point."
  (or (org-get-at-bol 'org-hd-marker)
      (org-get-at-bol 'org-marker)
      (user-error "No agenda item at point")))

(defun mod-org-agenda-visit ()
  "Visit the selected agenda item in the notes context."
  (interactive)
  (mod-context-notes-visit-marker (mod-org-agenda--marker-at-point)))

(provide 'mod-org)

;;; mod-org.el ends here
