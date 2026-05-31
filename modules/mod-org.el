;;; mod-org.el --- Org and agenda foundation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'org)
(require 'org-agenda)
(require 'org-attach)
(require 'org-clock)
(require 'org-id)
(require 'subr-x)

(declare-function org-roam-node-insert "org-roam-node")
(declare-function org-roam-node-read "org-roam-node" (&optional initial-input filter-fn sort-fn require-match))
(declare-function org-roam-node-title "org-roam-node")
(declare-function orbit-context-notes-visit-marker "orbit-context" (marker))
(declare-function xref-push-marker-stack "xref")

(defgroup mod-org nil
  "Minimal Org foundation."
  :group 'applications)

(defcustom mod-org-directory
  (or orbit-user-org-directory
      (expand-file-name "org/" (getenv "HOME")))
  "Base directory for Org notes and agenda files."
  :type 'directory)

(defcustom mod-org-main-file-name "notes.org"
  "Primary Org notes file name within `mod-org-directory'."
  :type 'string)

(defconst mod-org-default-files
  '("inbox.org" "tasks.org" "projects.org" "notes.org" "journal.org" "jira.org")
  "Default Org files expected under `mod-org-directory'.")

(defconst mod-org-agenda-work-view-key "w"
  "Custom agenda command key for the main work view.")

(defconst mod-org-capture-inbox-key "i"
  "Capture template key for inbox tasks.")

(defconst mod-org-capture-note-key "n"
  "Capture template key for quick notes.")

(defconst mod-org-capture-journal-key "j"
  "Capture template key for journal entries.")

(defconst mod-org-capture-linked-task-key "l"
  "Capture template key for a task linked to the current note.")

(defconst mod-org-capture-jira-follow-up-key "f"
  "Capture template key for a Jira follow-up task.")

(defconst mod-org-capture-investigation-key "d"
  "Capture template key for an investigation/debug note.")

(defconst mod-org-capture-meeting-action-key "m"
  "Capture template key for a meeting action.")

(defconst mod-org-capture-evidence-key "e"
  "Capture template key for a test evidence task.")

(defvar mod-org-return-fallback-command #'ignore
  "Fallback command used when `RET' is pressed away from an Org link.")

(defvar-local mod-org--property-drawers-hidden nil
  "Non-nil when Orbit has hidden property drawers in this Org buffer.")

(defun mod-org-enable-appearance ()
  "Apply Orbit's readable Org buffer defaults."
  (setq-local line-spacing 0.1)
  (when orbit-user-org-pretty
    (org-indent-mode 1))
  (when orbit-user-org-variable-pitch
    (variable-pitch-mode 1)))

(defun mod-org-toggle-pretty-view ()
  "Toggle Orbit's readable Org appearance in the current buffer."
  (interactive)
  (if (bound-and-true-p org-indent-mode)
      (progn
        (org-indent-mode -1)
        (setq-local line-spacing nil)
        (when (bound-and-true-p variable-pitch-mode)
          (variable-pitch-mode -1))
        (message "Org pretty view disabled"))
    (mod-org-enable-appearance)
    (message "Org pretty view enabled")))

(defun mod-org-toggle-emphasis-markers ()
  "Toggle visibility of Org emphasis markers in the current buffer."
  (interactive)
  (setq-local org-hide-emphasis-markers (not org-hide-emphasis-markers))
  (font-lock-flush)
  (font-lock-ensure)
  (message "Org emphasis markers %s"
           (if org-hide-emphasis-markers "hidden" "shown")))

(defun mod-org-toggle-property-drawers ()
  "Toggle visibility of property drawers in the current Org buffer."
  (interactive)
  (if mod-org--property-drawers-hidden
      (progn
        (org-fold-show-all)
        (setq-local mod-org--property-drawers-hidden nil)
        (message "Org property drawers shown"))
    (org-cycle-hide-drawers 'all)
    (setq-local mod-org--property-drawers-hidden t)
    (message "Org property drawers hidden")))

(defun mod-org-toggle-inline-images ()
  "Toggle inline images in the current Org buffer."
  (interactive)
  (if org-inline-image-overlays
      (progn
        (org-remove-inline-images)
        (message "Org inline images hidden"))
    (org-display-inline-images)
    (message "Org inline images shown")))

(defun mod-org--table-align-maybe ()
  "Align the current Org table when automatic table alignment is enabled."
  (when (and orbit-user-org-auto-align-tables
             (derived-mode-p 'org-mode)
             (org-at-table-p))
    (org-table-align)))

(defun mod-org--table-align-after-command (&rest _)
  "Align the current Org table after structural table commands."
  (mod-org--table-align-maybe))

(defun mod-org--install-table-alignment-advice ()
  "Install native Org table alignment advice once."
  (dolist (fn '(org-table-create-or-convert-from-region
                org-table-delete-column
                org-table-insert-column
                org-table-insert-row
                org-table-kill-row
                org-table-next-field
                org-table-next-row
                org-table-previous-field
                org-table-recalculate))
    (when (and (fboundp fn)
               (not (advice-member-p #'mod-org--table-align-after-command fn)))
      (advice-add fn :after #'mod-org--table-align-after-command))))

(defun mod-org-table-align ()
  "Align the Org table at point using Org's native text formatter."
  (interactive)
  (org-table-align))

(defun mod-org-table-create-or-convert-from-region ()
  "Create or convert an Org table, then align it."
  (interactive)
  (call-interactively #'org-table-create-or-convert-from-region))

(defun mod-org-table-recalculate ()
  "Recalculate the Org table at point, then align it."
  (interactive)
  (call-interactively #'org-table-recalculate))

(defun mod-org-table-next-row ()
  "Move to the next Org table row, then align the table."
  (interactive)
  (call-interactively #'org-table-next-row))

(defun mod-org-table-insert-row ()
  "Insert an Org table row, then align the table."
  (interactive)
  (call-interactively #'org-table-insert-row))

(defun mod-org-table-insert-column ()
  "Insert an Org table column, then align the table."
  (interactive)
  (call-interactively #'org-table-insert-column))

(defun mod-org-table-kill-row ()
  "Delete the current Org table row, then align the table."
  (interactive)
  (call-interactively #'org-table-kill-row))

(defun mod-org-table-delete-column ()
  "Delete the current Org table column, then align the table."
  (interactive)
  (call-interactively #'org-table-delete-column))

(defun mod-org-clock-heading ()
  "Return a modeline heading for the current Org clock.
When the clocked heading has a `JIRA_KEY' property, show only that key.
Otherwise fall back to the normal Org heading text."
  (or (org-entry-get (point) "JIRA_KEY")
      (if (org-before-first-heading-p)
          "???"
        (org-link-display-format
         (org-no-properties (org-get-heading t t t t))))))

(defun mod-org-main-file ()
  "Return the full path to the primary Org notes file."
  (expand-file-name mod-org-main-file-name mod-org-directory))

(defun mod-org-file (name)
  "Return the full path to Org file NAME within `mod-org-directory'."
  (expand-file-name name mod-org-directory))

(defun mod-org--context-link ()
  "Return an Org link to the current location, or nil."
  (when (and (derived-mode-p 'org-mode)
             (buffer-file-name))
    (save-excursion
      (unless (org-before-first-heading-p)
        (org-back-to-heading t))
      (let ((title (if (org-before-first-heading-p)
                       (file-name-base (buffer-file-name))
                     (org-get-heading t t t t)))
            (id (unless (org-before-first-heading-p)
                  (org-id-get-create))))
        (if id
            (format "[[id:%s][%s]]" id title)
          (format "[[file:%s][%s]]"
                  (file-relative-name (buffer-file-name) mod-org-directory)
                  title))))))

(defun mod-org--capture-linked-note-property ()
  "Return a LINKED_NOTE property drawer line for capture templates."
  (let ((link (if-let* ((buffer (plist-get org-capture-plist :original-buffer)))
                  (when (buffer-live-p buffer)
                    (with-current-buffer buffer
                      (mod-org--context-link)))
                (mod-org--context-link))))
    (if link
        (format ":PROPERTIES:\n:LINKED_NOTE: %s\n:END:\n" link)
      "")))

(defun mod-org--capture-jira-property ()
  "Prompt for and return a Jira property drawer for capture templates."
  (let ((key (string-trim (read-string "Jira key: "))))
    (if (string-empty-p key)
        ""
      (format ":PROPERTIES:\n:JIRA_KEY: %s\n:END:\n" key))))

(defun mod-org--agenda-prefix ()
  "Return compact traceability metadata for agenda entries."
  (let* ((jira (org-entry-get (point) "JIRA_KEY" t))
         (component (org-entry-get (point) "COMPONENT" t))
         (linked-note (org-entry-get (point) "LINKED_NOTE" t))
         (parts (delq nil
                      (list (and jira (format "[%s]" jira))
                            component
                            (and linked-note "note")))))
    (if parts
        (concat (string-join parts " ") " ")
      "")))

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

(defun mod-org-link-at-point-p ()
  "Return non-nil when point is on an Org link."
  (eq (org-element-type (org-element-context)) 'link))

(defun mod-org-push-link-location ()
  "Record the current location before following an Org link."
  (xref-push-marker-stack (point-marker)))

(defun mod-org-open-at-point-dwim ()
  "Follow an Org link at point, otherwise use the normal fallback."
  (interactive)
  (if (mod-org-link-at-point-p)
      (progn
        (mod-org-push-link-location)
        (org-open-at-point))
    (call-interactively mod-org-return-fallback-command)))

(defun mod-org-open-link-at-point ()
  "Open the Org link at point and record jump history."
  (interactive)
  (if (mod-org-link-at-point-p)
      (progn
        (mod-org-push-link-location)
        (org-open-at-point))
    (user-error "No Org link at point")))

(defun mod-org-insert-node-link ()
  "Insert a link to an org-roam node."
  (interactive)
  (if (fboundp 'org-roam-node-insert)
      (call-interactively #'org-roam-node-insert)
    (call-interactively #'org-insert-link)))

(defun mod-org--heading-link-candidates ()
  "Return completion candidates for headings in Org agenda files."
  (let ((files (delete-dups
                (cl-remove-if-not
                 #'file-readable-p
                 (append (org-agenda-files)
                         (when (file-directory-p mod-org-directory)
                           (directory-files-recursively mod-org-directory "\\.org\\'"))))))
        candidates)
    (dolist (file files)
      (with-temp-buffer
        (insert-file-contents file)
        (org-mode)
        (org-with-wide-buffer
         (org-map-entries
          (lambda ()
            (let* ((title (org-get-heading t t t t))
                   (olp (string-join (org-get-outline-path t t) " > "))
                   (display (format "%s  (%s)"
                                    (if (string-empty-p olp) title olp)
                                    (file-relative-name file mod-org-directory))))
              (push (list display file (point) title) candidates)))
          nil 'file))))
    (nreverse candidates)))

(defun mod-org-insert-heading-link ()
  "Insert an ID link to a heading selected with completion."
  (interactive)
  (let* ((candidates (mod-org--heading-link-candidates))
         (choice (completing-read "Heading: " (mapcar #'car candidates) nil t))
         (entry (assoc choice candidates))
         (file (nth 1 entry))
         (position (nth 2 entry))
         (title (nth 3 entry)))
    (unless entry
      (user-error "No heading selected"))
    (let ((id (with-current-buffer (find-file-noselect file)
                (save-excursion
                  (goto-char position)
                  (org-id-get-create)))))
      (insert (format "[[id:%s][%s]]" id title)))))

(defun mod-org-attach-file (file)
  "Attach FILE to the current Org heading."
  (interactive "fAttach file: ")
  (unless (derived-mode-p 'org-mode)
    (user-error "Org attachments are only available in Org buffers"))
  (org-attach-attach file nil 'cp)
  (message "Attached %s" (file-name-nondirectory file)))

(defun mod-org-attachment-directory ()
  "Open the current heading's Org attachment directory."
  (interactive)
  (let ((directory (org-attach-dir t)))
    (make-directory directory t)
    (dired directory)))

(defun mod-org--attachment-files ()
  "Return files attached to the current Org heading."
  (let ((directory (org-attach-dir t)))
    (when (file-directory-p directory)
      (cl-remove-if
       (lambda (file)
         (member (file-name-nondirectory file) '("." "..")))
       (directory-files directory)))))

(defun mod-org-insert-attached-image ()
  "Insert an Org attachment link to an attached image."
  (interactive)
  (let* ((files (mod-org--attachment-files))
         (images (cl-remove-if-not
                  (lambda (file)
                    (string-match-p
                     (rx "." (or "png" "jpg" "jpeg" "gif" "svg" "webp") eos)
                     (downcase file)))
                  files))
         (choice (completing-read
                  "Image: " (mapcar #'file-name-nondirectory images) nil t)))
    (unless images
      (user-error "No attached images for this heading"))
    (insert (format "[[attachment:%s]]" choice))
    (org-display-inline-images)))

(defun mod-org-tab-dwim ()
  "Run the expected Org TAB behavior.
Inside Org tables, move to the next field and realign the table.  Everywhere
else, fall back to normal Org cycling."
  (interactive)
  (if (org-at-table-p)
      (org-table-next-field)
    (org-cycle)))

(defun mod-org-backtab-dwim ()
  "Run the expected Org backtab behavior.
Inside Org tables, move to the previous field.  Everywhere else, fall back to
normal Org shift-cycling."
  (interactive)
  (if (org-at-table-p)
      (org-table-previous-field)
    (org-shifttab)))

(setq org-directory mod-org-directory
      org-default-notes-file (mod-org-main-file)
      org-clock-heading-function #'mod-org-clock-heading
      org-adapt-indentation nil
      org-auto-align-tags nil
      org-catch-invisible-edits 'smart
      org-cycle-separator-lines 1
      org-ellipsis " ▾"
      org-fontify-done-headline t
      org-fontify-quote-and-verse-blocks t
      org-fontify-whole-heading-line t
      org-hide-emphasis-markers t
      org-image-actual-width '(640)
      org-insert-heading-respect-content t
      org-log-into-drawer "LOGBOOK"
      org-log-done 'time
      org-pretty-entities t
      org-return-follows-link t
      org-special-ctrl-a/e t
      org-src-fontify-natively t
      org-src-tab-acts-natively t
      org-startup-indented orbit-user-org-pretty
      org-tags-column 0
      org-attach-id-dir "attach"
      org-use-tag-inheritance t
      org-tag-alist '(("ccsds" . ?c)
                      ("spacecraft" . ?s)
                      ("ground" . ?g)
                      ("test" . ?t)
                      ("ops" . ?o)
                      ("sim" . ?m)
                      ("flight" . ?f)
                      ("requirement" . ?r)
                      ("procedure" . ?p)
                      ("interface" . ?i)
                      ("standard" . ?S)
                      ("decision" . ?d)
                      ("risk" . ?k)
                      ("jira" . ?j)
                      ("review" . ?v)
                      ("blocked" . ?b)
                      ("evidence" . ?e)
                      ("followup" . ?u))
      org-global-properties '(("JIRA_KEY_ALL" . "")
                              ("COMPONENT_ALL" . "")
                              ("MISSION_ALL" . "")
                              ("STANDARD_ALL" . "")
                              ("REQUIREMENT_ALL" . "")
                              ("LINKED_NOTE_ALL" . "")
                              ("EVIDENCE_ALL" . ""))
      org-todo-keyword-faces '(("TODO" . org-todo)
                               ("NEXT" . (:inherit org-todo :weight bold))
                               ("IN-PROGRESS" . (:inherit org-todo :weight bold))
                               ("WAIT" . (:inherit org-warning :weight bold))
                               ("DONE" . org-done)
                               ("CANCELLED" . shadow))
      org-agenda-prefix-format '((agenda . " %?-12t %(mod-org--agenda-prefix)")
                                 (todo . " %(mod-org--agenda-prefix)")
                                 (tags . " %(mod-org--agenda-prefix)")
                                 (search . " %(mod-org--agenda-prefix)"))
      org-link-frame-setup '((file . find-file)
                             (vm . vm-visit-folder)
                             (vm-imap . vm-visit-imap-folder)
                             (gnus . org-gnus-no-new-news)
                             (file+emacs . find-file))
      org-capture-templates
      `((,mod-org-capture-inbox-key "Inbox task" entry
         (file ,(mod-org-file "inbox.org"))
         "* TODO %?\n%U\n:PROPERTIES:\n:COMPONENT: \n:MISSION: \n:END:\n")
        (,mod-org-capture-linked-task-key "Linked task" entry
         (file ,(mod-org-file "tasks.org"))
         "* TODO %?\n%U\n%(mod-org--capture-linked-note-property)")
        (,mod-org-capture-jira-follow-up-key "Jira follow-up" entry
         (file ,(mod-org-file "tasks.org"))
         "* TODO %?\n%U\n%(mod-org--capture-jira-property)")
        (,mod-org-capture-investigation-key "Investigation" entry
         (file ,(mod-org-file "notes.org"))
         "* %? :investigation:\n%U\n\n** Context\n\n** Findings\n\n** Next actions\n")
        (,mod-org-capture-meeting-action-key "Meeting action" entry
         (file ,(mod-org-file "tasks.org"))
         "* TODO %? :followup:\n%U\n%(mod-org--capture-linked-note-property)")
        (,mod-org-capture-evidence-key "Test evidence" entry
         (file ,(mod-org-file "tasks.org"))
         "* TODO %? :evidence:test:\n%U\n:PROPERTIES:\n:EVIDENCE: \n:END:\n")
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
                  ((org-agenda-overriding-header "Schedule")
                   (org-agenda-span 1)
                   (org-deadline-warning-days 0)))
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
                 (org-agenda-skip-function #'mod-org--agenda-skip-triage)))))
        ("i" "Inbox / triage"
         ((todo "TODO"
                ((org-agenda-overriding-header "Inbox")
                 (org-agenda-skip-function #'mod-org--agenda-skip-unless-inbox)))
          (todo "TODO"
                ((org-agenda-overriding-header "Triage")
                 (org-agenda-skip-function #'mod-org--agenda-skip-triage)))))
        ("b" "Blocked / waiting"
         ((todo "WAIT"
                ((org-agenda-overriding-header "Waiting")))
          (tags-todo "blocked"
                     ((org-agenda-overriding-header "Blocked")))))
        ("r" "Review / follow-up"
         ((tags-todo "review"
                     ((org-agenda-overriding-header "Review")))
          (tags-todo "followup"
                     ((org-agenda-overriding-header "Follow-up")))))
        ("e" "Evidence / test"
         ((tags-todo "evidence"
                     ((org-agenda-overriding-header "Evidence")))
          (tags-todo "test"
                     ((org-agenda-overriding-header "Test")))))
        ("j" "Jira-linked work"
         ((tags-todo "jira"
                     ((org-agenda-overriding-header "Tagged Jira")))
          (todo ""
                ((org-agenda-overriding-header "Jira key")
                 (org-agenda-skip-function
                  (lambda ()
                    (unless (org-entry-get (point) "JIRA_KEY" t)
                      (or (outline-next-heading)
                          (point-max)))))))))))

(mod-org-refresh-agenda-files)
(org-clock-load)

;; org-babel: enable code block execution for common languages.
;; Security: always prompt before evaluating any block.
(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (python     . t)
   (shell      . t)))

(setq org-confirm-babel-evaluate t
      org-babel-python-command "python3")

(add-hook 'org-mode-hook #'mod-org-enable-appearance)
(mod-org--install-table-alignment-advice)

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

(defun mod-org-capture-linked-task ()
  "Capture a task linked to the current Org note."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture nil mod-org-capture-linked-task-key))

(defun mod-org-capture-jira-follow-up ()
  "Capture a Jira follow-up task."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture nil mod-org-capture-jira-follow-up-key))

(defun mod-org-capture-investigation ()
  "Capture an investigation/debug note."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture nil mod-org-capture-investigation-key))

(defun mod-org-capture-meeting-action ()
  "Capture a meeting action."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture nil mod-org-capture-meeting-action-key))

(defun mod-org-capture-evidence ()
  "Capture a test evidence task."
  (interactive)
  (mod-org--ensure-default-files)
  (org-capture nil mod-org-capture-evidence-key))

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
  (orbit-context-notes-visit-marker (mod-org-agenda--marker-at-point)))

(provide 'mod-org)

;;; mod-org.el ends here
