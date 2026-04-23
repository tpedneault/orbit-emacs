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

(defconst mod-org-capture-inbox-key "i"
  "Capture template key for inbox tasks.")

(defconst mod-org-capture-note-key "n"
  "Capture template key for quick notes.")

(defconst mod-org-capture-journal-key "j"
  "Capture template key for journal entries.")

(defun mod-org-main-file ()
  "Return the full path to the primary Org notes file."
  (expand-file-name mod-org-main-file-name mod-org-directory))

(defun mod-org-file (name)
  "Return the full path to Org file NAME within `mod-org-directory'."
  (expand-file-name name mod-org-directory))

(defun mod-org--ensure-directory ()
  "Ensure the Org directory exists."
  (make-directory mod-org-directory t))

(defun mod-org--ensure-default-files ()
  "Ensure the default Org files exist."
  (mod-org--ensure-directory)
  (dolist (name mod-org-default-files)
    (let ((file (mod-org-file name)))
      (unless (file-exists-p file)
        (write-region "" nil file nil 'silent)))))

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

(defun mod-org--agenda-skip-unless-inbox ()
  "Skip entries that are not from `inbox.org'."
  (unless (equal (buffer-file-name (buffer-base-buffer))
                 (mod-org-file "inbox.org"))
    (or (outline-next-heading)
        (point-max))))

(defun mod-org--agenda-skip-if-inbox ()
  "Skip entries that are from `inbox.org'."
  (when (equal (buffer-file-name (buffer-base-buffer))
               (mod-org-file "inbox.org"))
    (or (outline-next-heading)
        (point-max))))

(defun mod-org--agenda-skip-triage ()
  "Skip entries that should not appear in the triage section."
  (or (mod-org--agenda-skip-scheduled-or-deadline)
      (mod-org--agenda-skip-if-inbox)))

(setq org-directory mod-org-directory
      org-default-notes-file (mod-org-main-file)
      org-log-into-drawer "LOGBOOK"
      org-log-done 'time
      org-capture-templates
      `((,mod-org-capture-inbox-key "Inbox task" entry
         (file ,(mod-org-file "inbox.org"))
         "* TODO %?\n%U\n")
        (,mod-org-capture-note-key "Quick note" entry
         (file ,(mod-org-file "notes.org"))
         "* %?\n%U\n")
        (,mod-org-capture-journal-key "Journal entry" entry
         (file+olp+datetree ,(mod-org-file "journal.org"))
         "* %?\n%U\n"))
      org-refile-targets '((org-agenda-files :maxlevel . 3))
      org-refile-use-outline-path 'file
      org-outline-path-complete-in-steps nil
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
                   (org-deadline-warning-days 0)
                   (org-agenda-overriding-header "Schedule")))
          (todo "IN-PROGRESS"
                ((org-agenda-overriding-header "In Progress")))
          (todo "NEXT"
                ((org-agenda-overriding-header "Next")))
          (todo "WAIT"
                ((org-agenda-overriding-header "Waiting")))
          (todo "TODO"
                ((org-agenda-overriding-header "Inbox")
                 (org-agenda-skip-function #'mod-org--agenda-skip-unless-inbox)))
          (todo "TODO"
                ((org-agenda-overriding-header "Triage")
                 (org-agenda-skip-function #'mod-org--agenda-skip-triage)))))))

(mod-org-refresh-agenda-files)

(defun mod-org-open-notes ()
  "Open the primary Org notes file."
  (interactive)
  (mod-org--ensure-default-files)
  (find-file (mod-org-main-file)))

(defun mod-org-capture ()
  "Run the general Org capture dispatcher."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture))

(defun mod-org-capture-inbox-task ()
  "Capture a new inbox task."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture nil mod-org-capture-inbox-key))

(defun mod-org-capture-note ()
  "Capture a quick note."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture nil mod-org-capture-note-key))

(defun mod-org-capture-journal ()
  "Capture a journal entry."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture nil mod-org-capture-journal-key))

(defun mod-org-open-agenda ()
  "Open the Org agenda."
  (interactive)
  (mod-org--ensure-default-files)
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
