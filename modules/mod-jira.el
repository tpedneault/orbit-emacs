;;; mod-jira.el --- Read-only Jira to Org sync -*- lexical-binding: t; -*-

(require 'browse-url)
(require 'json)
(require 'org)
(require 'subr-x)
(require 'url)
(require 'url-http)
(require 'url-util)

(declare-function mod-org-file "mod-org" (name))
(declare-function mod-org-refresh-agenda-files "mod-org")

(defgroup mod-jira nil
  "Read-only Jira sync into Org."
  :group 'applications)

(defconst mod-jira-default-api-prefix "/rest/api/2"
  "Default Jira REST API prefix for Server/Data Center.")

(defconst mod-jira-sync-buffer-name "*jira-sync*"
  "Temporary buffer name used during Jira sync requests.")

(defun mod-jira-api-prefix ()
  "Return the configured Jira API prefix."
  (or orbit-user-jira-api-prefix
      mod-jira-default-api-prefix))

(defun mod-jira-base-url ()
  "Return the configured Jira base URL without a trailing slash."
  (when orbit-user-jira-base-url
    (replace-regexp-in-string "/\\'" "" orbit-user-jira-base-url)))

(defun mod-jira-org-file ()
  "Return the Org file used for Jira issue sync."
  (or orbit-user-jira-org-file
      (if (fboundp 'mod-org-file)
          (mod-org-file "jira.org")
        (expand-file-name "jira.org"
                          (expand-file-name "org/" (getenv "HOME"))))))

(defun mod-jira--token ()
  "Return the configured Jira token, or nil."
  (let ((token
         (cond
          (orbit-user-jira-token-command
           (string-trim (shell-command-to-string orbit-user-jira-token-command)))
          (orbit-user-jira-pat-env
           (string-trim (or (getenv orbit-user-jira-pat-env) "")))
          (t ""))))
    (unless (string-empty-p token)
      token)))

(defun mod-jira--built-jql ()
  "Return the default generated JQL, or nil when config is incomplete."
  (when (and orbit-user-jira-project-key orbit-user-jira-username)
    (format
     "project = %s AND assignee = %s AND resolution = Unresolved ORDER BY updated DESC"
     orbit-user-jira-project-key
     orbit-user-jira-username)))

(defun mod-jira-jql ()
  "Return the Jira JQL to use for sync."
  (or orbit-user-jira-jql
      (mod-jira--built-jql)))

(defun mod-jira--ensure-config ()
  "Validate Jira configuration and return a plist of resolved settings."
  (let ((base-url (mod-jira-base-url))
        (token (mod-jira--token))
        (jql (mod-jira-jql)))
    (unless base-url
      (user-error "Jira base URL is not configured: set orbit-user-jira-base-url"))
    (unless token
      (user-error
       "Jira token is not configured: set orbit-user-jira-token-command or orbit-user-jira-pat-env"))
    (unless jql
      (user-error
       (concat
        "Jira JQL is not configured: set orbit-user-jira-jql, "
        "or set orbit-user-jira-project-key and orbit-user-jira-username")))
    (list :base-url base-url
          :token token
          :jql jql
          :org-file (mod-jira-org-file))))

(defun mod-jira--request-url (jql start-at max-results)
  "Return the search URL for JQL starting at START-AT with MAX-RESULTS."
  (concat
   (mod-jira-base-url)
   (mod-jira-api-prefix)
   "/search?"
   (url-build-query-string
    `(("jql" ,jql)
      ("startAt" ,(number-to-string start-at))
      ("maxResults" ,(number-to-string max-results))
      ("fields" "summary,status,assignee,priority,updated")))))

(defun mod-jira--http-status ()
  "Return the HTTP status code from the current response buffer."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "HTTP/[0-9.]+ \\([0-9]+\\)" nil t)
        (string-to-number (match-string 1))
      0)))

(defun mod-jira--request-json (url token)
  "Fetch URL with TOKEN and return parsed JSON."
  (let ((url-request-method "GET")
        (url-request-extra-headers
         `(("Accept" . "application/json")
           ("Authorization" . ,(concat "Bearer " token)))))
    (with-current-buffer (or (url-retrieve-synchronously url t t)
                             (user-error "Jira request failed for %s" url))
      (unwind-protect
          (let ((status (mod-jira--http-status)))
            (unless (= status 200)
              (user-error "Jira request failed with HTTP %s" status))
            (goto-char (or url-http-end-of-headers (point-min)))
            (json-parse-buffer :object-type 'alist :array-type 'list))
        (kill-buffer (current-buffer))))))

(defun mod-jira--issue-url (base-url key)
  "Return the browser URL for issue KEY under BASE-URL."
  (concat base-url "/browse/" key))

(defun mod-jira--simplify-issue (issue base-url)
  "Return a simplified plist for Jira ISSUE using BASE-URL."
  (let* ((key (alist-get 'key issue))
         (fields (alist-get 'fields issue))
         (status (alist-get 'name (alist-get 'status fields)))
         (assignee (alist-get 'displayName (alist-get 'assignee fields)))
         (priority (alist-get 'name (alist-get 'priority fields)))
         (summary (alist-get 'summary fields))
         (updated (alist-get 'updated fields)))
    (list :key key
          :summary (or summary "")
          :status (or status "Unknown")
          :assignee (or assignee "Unassigned")
          :priority (or priority "None")
          :updated (or updated "")
          :url (mod-jira--issue-url base-url key))))

(defun mod-jira-fetch-issues ()
  "Fetch Jira issues for the configured JQL."
  (pcase-let* ((`(:base-url ,base-url :token ,token :jql ,jql) (mod-jira--ensure-config))
               (start-at 0)
               (max-results 100)
               (issues '())
               (total nil))
    (while (or (null total) (< start-at total))
      (let* ((payload (mod-jira--request-json
                       (mod-jira--request-url jql start-at max-results)
                       token))
             (page-issues (alist-get 'issues payload)))
        (setq total (alist-get 'total payload))
        (setq issues
              (append issues
                      (mapcar (lambda (issue)
                                (mod-jira--simplify-issue issue base-url))
                              page-issues)))
        (setq start-at (+ start-at (length page-issues)))
        (when (zerop (length page-issues))
          (setq start-at total))))
    issues))

(defun mod-jira--file-heading-notes ()
  "Return an alist of Jira key to preserved note text from the current file."
  (let ((file (mod-jira-org-file))
        (notes '()))
    (when (file-exists-p file)
      (with-current-buffer (find-file-noselect file)
        (org-with-wide-buffer
          (goto-char (point-min))
          (org-map-entries
           (lambda ()
             (when-let* ((key (org-entry-get (point) "JIRA_KEY")))
               (let ((body-start (save-excursion
                                   (org-back-to-heading t)
                                   (org-end-of-meta-data t)
                                   (point)))
                     (body-end (save-excursion
                                 (org-end-of-subtree t t))))
                 (push (cons key
                             (string-trim-right
                              (buffer-substring-no-properties body-start body-end)))
                       notes))))
           nil
           'file))))
    notes))

(defun mod-jira--insert-issue (issue preserved-notes)
  "Insert ISSUE into the current Org buffer, using PRESERVED-NOTES when present."
  (let* ((key (plist-get issue :key))
         (notes (alist-get key preserved-notes nil nil #'string=)))
    (insert (format "* %s %s\n"
                    key
                    (string-trim (plist-get issue :summary))))
    (insert ":PROPERTIES:\n")
    (insert (format ":JIRA_KEY: %s\n" key))
    (insert (format ":JIRA_STATUS: %s\n" (plist-get issue :status)))
    (insert (format ":JIRA_ASSIGNEE: %s\n" (plist-get issue :assignee)))
    (insert (format ":JIRA_PRIORITY: %s\n" (plist-get issue :priority)))
    (insert (format ":JIRA_UPDATED: %s\n" (plist-get issue :updated)))
    (insert (format ":JIRA_URL: %s\n" (plist-get issue :url)))
    (insert ":END:\n")
    (when (and notes (not (string-empty-p notes)))
      (insert "\n" notes)
      (unless (string-suffix-p "\n" notes)
        (insert "\n")))
    (insert "\n")))

(defun mod-jira--write-issues-file (issues)
  "Write ISSUES into the configured Jira Org file."
  (let* ((file (mod-jira-org-file))
         (directory (file-name-directory file))
         (preserved-notes (mod-jira--file-heading-notes)))
    (make-directory directory t)
    (with-temp-buffer
      (insert "#+title: jira\n\n")
      (insert (format "#+startup: overview\n\n"))
      (insert (format "# Synced: %s\n\n" (format-time-string "%Y-%m-%d %H:%M")))
      (dolist (issue issues)
        (mod-jira--insert-issue issue preserved-notes))
      (write-region (point-min) (point-max) file nil 'silent))
    (when (fboundp 'mod-org-refresh-agenda-files)
      (mod-org-refresh-agenda-files))))

(defun mod-jira-sync ()
  "Fetch configured Jira issues and sync them into the Jira Org file."
  (interactive)
  (let ((issues (mod-jira-fetch-issues))
        (file (mod-jira-org-file)))
    (mod-jira--write-issues-file issues)
    (message "Synced %d Jira issues to %s" (length issues) file)))

(defun mod-jira--issue-url-at-point ()
  "Return the Jira issue URL stored at point, or nil."
  (or (org-entry-get (point) "JIRA_URL" 'inherit)
      (when-let* ((key (org-entry-get (point) "JIRA_KEY" 'inherit))
                  (base-url (mod-jira-base-url)))
        (mod-jira--issue-url base-url key))))

(defun mod-jira-open-issue ()
  "Open the Jira issue at point in a browser."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Jira issue opening expects an Org buffer"))
  (if-let* ((url (mod-jira--issue-url-at-point)))
      (browse-url url)
    (user-error "No Jira issue metadata found at point")))

(provide 'mod-jira)

;;; mod-jira.el ends here
