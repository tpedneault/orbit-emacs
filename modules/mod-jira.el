;;; mod-jira.el --- Read-only Jira to Org sync -*- lexical-binding: t; -*-

(require 'browse-url)
(require 'json)
(require 'org-clock)
(require 'org)
(require 'subr-x)
(require 'url)
(require 'url-http)
(require 'url-util)

(declare-function mod-org-file "mod-org" (name))
(declare-function mod-org-refresh-agenda-files "mod-org")
(declare-function mod-context-notes-visit-marker "mod-context" (marker))

(defgroup mod-jira nil
  "Read-only Jira sync into Org."
  :group 'applications)

(defconst mod-jira-default-api-prefix "/rest/api/2"
  "Default Jira REST API prefix for Server/Data Center.")

(defconst mod-jira-sync-buffer-name "*jira-sync*"
  "Temporary buffer name used during Jira sync requests.")

(defconst mod-jira-tag "JIRA"
  "Tag applied to synced Jira headings.")

(defconst mod-jira-managed-section-names '("Description" "Comments" "Notes")
  "Level-two Jira section names used under synced issue headings.")

(defconst mod-jira-worklog-marker-prefix "- Jira worklog submitted:"
  "Marker prefix inserted after CLOCK lines once submitted to Jira.")

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

(defun mod-jira--ensure-org-file ()
  "Ensure the Jira Org file exists."
  (let ((file (mod-jira-org-file)))
    (make-directory (file-name-directory file) t)
    (unless (file-exists-p file)
      (write-region "#+title: jira\n\n" nil file nil 'silent))
    file))

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

(defun mod-jira--ensure-base-config ()
  "Validate Jira base configuration for requests that do not need JQL."
  (let ((base-url (mod-jira-base-url))
        (token (mod-jira--token)))
    (unless base-url
      (user-error "Jira base URL is not configured: set orbit-user-jira-base-url"))
    (unless token
      (user-error
       "Jira token is not configured: set orbit-user-jira-token-command or orbit-user-jira-pat-env"))
    (list :base-url base-url
          :token token
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
      ("fields" "summary,status,assignee,priority,updated,description,comment")))))

(defun mod-jira--issue-request-url (key)
  "Return the issue URL for Jira issue KEY."
  (concat
   (mod-jira-base-url)
   (mod-jira-api-prefix)
   "/issue/"
   (url-hexify-string key)
   "?"
   (url-build-query-string
    '(("fields" "summary,status,assignee,priority,updated,description,comment")))))

(defun mod-jira--issue-comment-url (key)
  "Return the comment endpoint URL for Jira issue KEY."
  (concat (mod-jira-base-url)
          (mod-jira-api-prefix)
          "/issue/"
          (url-hexify-string key)
          "/comment"))

(defun mod-jira--issue-transitions-url (key)
  "Return the transitions endpoint URL for Jira issue KEY."
  (concat (mod-jira-base-url)
          (mod-jira-api-prefix)
          "/issue/"
          (url-hexify-string key)
          "/transitions"))

(defun mod-jira--issue-worklog-url (key)
  "Return the worklog endpoint URL for Jira issue KEY."
  (concat (mod-jira-base-url)
          (mod-jira-api-prefix)
          "/issue/"
          (url-hexify-string key)
          "/worklog"))

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

(defun mod-jira--request-data (method url token &optional payload success-statuses)
  "Send METHOD to URL with TOKEN and optional JSON PAYLOAD.
Return parsed JSON when available. SUCCESS-STATUSES defaults to '(200 201 204)."
  (let ((url-request-method method)
        (url-request-extra-headers
         (append
          `(("Accept" . "application/json")
            ("Authorization" . ,(concat "Bearer " token)))
          (when payload
            '(("Content-Type" . "application/json")))))
        (url-request-data (when payload (json-encode payload)))
        (ok-statuses (or success-statuses '(200 201 204))))
    (with-current-buffer (or (url-retrieve-synchronously url t t)
                             (user-error "Jira request failed for %s" url))
      (unwind-protect
          (let ((status (mod-jira--http-status)))
            (unless (memq status ok-statuses)
              (user-error "Jira request failed with HTTP %s" status))
            (goto-char (or url-http-end-of-headers (point-min)))
            (unless (eobp)
              (condition-case nil
                  (json-parse-buffer :object-type 'alist :array-type 'list)
                (error nil))))
        (kill-buffer (current-buffer))))))

(defun mod-jira--issue-url (base-url key)
  "Return the browser URL for issue KEY under BASE-URL."
  (concat base-url "/browse/" key))

(defun mod-jira--extract-text (value)
  "Return a readable text rendering for Jira VALUE."
  (cond
   ((null value) "")
   ((stringp value) value)
   ((vectorp value)
    (mod-jira--extract-text (append value nil)))
   ((listp value)
    (if (and value (consp (car value)))
        (let* ((text (alist-get 'text value))
               (content (alist-get 'content value))
               (parts (delq nil
                            (mapcar (lambda (item)
                                      (let ((item-text (mod-jira--extract-text item)))
                                        (unless (string-empty-p item-text)
                                          item-text)))
                                    content))))
          (string-trim
           (string-join
            (delq nil (append (and text (list text)) parts))
            "\n")))
      (string-trim
       (string-join
        (delq nil
              (mapcar (lambda (item)
                        (let ((text (mod-jira--extract-text item)))
                          (unless (string-empty-p text)
                            text)))
                      value))
        "\n"))))
   (t (format "%s" value))))

(defun mod-jira--extract-comments (fields)
  "Return a simplified comment list extracted from Jira FIELDS."
  (mapcar
   (lambda (comment)
     (list :author (or (alist-get 'displayName (alist-get 'author comment))
                       "Unknown")
           :created (or (alist-get 'created comment) "")
           :body (mod-jira--extract-text (alist-get 'body comment))))
   (alist-get 'comments (alist-get 'comment fields))))

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
          :description (mod-jira--extract-text (alist-get 'description fields))
          :comments (mod-jira--extract-comments fields)
          :url (mod-jira--issue-url base-url key))))

(defun mod-jira--todo-keyword (status)
  "Map Jira STATUS to an Org TODO keyword."
  (pcase (downcase (or status ""))
    ((or "to do" "open" "reopened") "TODO")
    ("in progress" "IN-PROGRESS")
    ((or "blocked" "waiting") "WAIT")
    ((or "done" "closed" "resolved") "DONE")
    (_ "TODO")))

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

(defun mod-jira-fetch-issue (key)
  "Fetch Jira issue KEY using the configured Jira connection."
  (pcase-let* ((`(:base-url ,base-url :token ,token) (mod-jira--ensure-base-config))
               (payload (mod-jira--request-json
                         (mod-jira--issue-request-url key)
                         token)))
    (mod-jira--simplify-issue payload base-url)))

(defun mod-jira--normalize-issue-key (identifier)
  "Return a Jira issue key for IDENTIFIER."
  (let ((trimmed (string-trim identifier)))
    (cond
     ((string-match-p "\\`[A-Za-z][A-Za-z0-9_]*-[0-9]+\\'" trimmed)
      (upcase trimmed))
     ((string-match-p "\\`[0-9]+\\'" trimmed)
      (unless orbit-user-jira-project-key
        (user-error
         "Bare Jira issue IDs require orbit-user-jira-project-key to be configured"))
      (format "%s-%s" orbit-user-jira-project-key trimmed))
     (t
      (user-error "Enter a Jira issue key like PROJ-75 or a bare number like 75")))))

(defun mod-jira--section-body (start)
  "Return body text for the subtree heading at START."
  (save-excursion
    (goto-char start)
    (org-back-to-heading t)
    (let ((body-start (progn
                        (org-end-of-meta-data t)
                        (point)))
          (body-end (save-excursion
                      (org-end-of-subtree t t))))
      (string-trim-right
       (buffer-substring-no-properties body-start body-end)))))

(defun mod-jira--level-two-sections (issue-level subtree-end)
  "Return preserved level-two section data below ISSUE-LEVEL until SUBTREE-END."
  (let ((notes "")
        (extras '()))
    (save-excursion
      (while (re-search-forward org-heading-regexp subtree-end t)
        (let* ((element (org-element-at-point))
               (level (org-element-property :level element))
               (title (org-element-property :raw-value element)))
          (when (= level (1+ issue-level))
            (let ((body (mod-jira--section-body (point))))
              (cond
               ((string= title "Notes")
                (setq notes body))
               ((member title '("Description" "Comments"))
                nil)
               (t
                (push (concat "** " title "\n"
                              (unless (string-empty-p body)
                                (concat body "\n")))
                      extras))))
            (goto-char (save-excursion
                         (org-end-of-subtree t t)
                         (point)))))))
    (list :notes (string-trim-right
                  (string-join
                   (delq nil
                         (list (unless (string-empty-p notes) notes)
                               (unless (null extras)
                                 (string-trim-right
                                  (string-join (nreverse extras) "\n")))))
                   "\n\n")))))

(defun mod-jira--file-heading-data ()
  "Return an alist of Jira key to preserved heading data from the current file."
  (let ((file (mod-jira--ensure-org-file))
        (entries '()))
    (when (file-exists-p file)
      (with-current-buffer (find-file-noselect file)
        (org-with-wide-buffer
          (goto-char (point-min))
          (org-map-entries
           (lambda ()
             (when-let* ((key (org-entry-get (point) "JIRA_KEY")))
               (let* ((body-start (save-excursion
                                    (org-back-to-heading t)
                                    (org-end-of-meta-data t)
                                    (point)))
                      (body-end (save-excursion
                                  (org-end-of-subtree t t)))
                      (issue-level (org-outline-level))
                      (legacy-prefix
                       (save-excursion
                         (goto-char body-start)
                         (let ((first-child
                                (save-excursion
                                  (when (re-search-forward org-heading-regexp body-end t)
                                    (line-beginning-position)))))
                           (string-trim-right
                            (buffer-substring-no-properties
                             body-start
                             (or first-child body-end))))))
                      (section-data (mod-jira--level-two-sections issue-level body-end))
                      (notes (string-trim-right
                              (string-join
                               (delq nil
                                     (list (unless (string-empty-p legacy-prefix)
                                             legacy-prefix)
                                           (let ((preserved (plist-get section-data :notes)))
                                             (unless (string-empty-p preserved)
                                               preserved))))
                               "\n\n")))
                      (tags (seq-remove
                             (lambda (tag)
                               (string= tag mod-jira-tag))
                             (org-get-tags nil t))))
                 (push (cons key (list :notes notes :tags tags))
                       entries))))
           nil
           'file))))
    entries))

(defun mod-jira--issue-heading-data-at-point ()
  "Return preserved Jira heading data for the issue subtree at point."
  (save-excursion
    (mod-jira--goto-issue-heading)
    (let* ((key (org-entry-get (point) "JIRA_KEY"))
           (body-start (save-excursion
                         (org-back-to-heading t)
                         (org-end-of-meta-data t)
                         (point)))
           (body-end (save-excursion
                       (org-end-of-subtree t t)))
           (issue-level (org-outline-level))
           (legacy-prefix
            (save-excursion
              (goto-char body-start)
              (let ((first-child
                     (save-excursion
                       (when (re-search-forward org-heading-regexp body-end t)
                         (line-beginning-position)))))
                (string-trim-right
                 (buffer-substring-no-properties
                  body-start
                  (or first-child body-end))))))
           (section-data (mod-jira--level-two-sections issue-level body-end))
           (notes (string-trim-right
                   (string-join
                    (delq nil
                          (list (unless (string-empty-p legacy-prefix)
                                  legacy-prefix)
                                (let ((preserved (plist-get section-data :notes)))
                                  (unless (string-empty-p preserved)
                                    preserved))))
                    "\n\n")))
           (tags (seq-remove
                  (lambda (tag)
                    (string= tag mod-jira-tag))
                  (org-get-tags nil t))))
      (list :key key
            :notes notes
            :tags tags))))

(defun mod-jira--goto-issue-heading ()
  "Move point to the owning Jira issue heading, or signal a clear error."
  (unless (derived-mode-p 'org-mode)
    (user-error "Jira issue refresh expects an Org buffer"))
  (org-back-to-heading t)
  (let ((found nil))
    (while (and (not found) (point))
      (if (org-entry-get (point) "JIRA_KEY")
          (setq found t)
        (condition-case nil
            (outline-up-heading 1 t)
          (error
           (goto-char (point-min))
           (setq found 'missing)))))
    (unless (eq found t)
      (user-error "Point is not inside a Jira issue subtree"))
    (point)))

(defun mod-jira--heading-tags-string (tags)
  "Return a heading tag suffix for TAGS."
  (let ((all-tags (cl-remove-duplicates
                   (append tags (list mod-jira-tag))
                   :test #'string=)))
    (if all-tags
        (concat " :" (string-join all-tags ":") ":")
      "")))

(defun mod-jira--insert-managed-text (text)
  "Insert TEXT as readable Org body content."
  (let ((content (string-trim-right (or text ""))))
    (if (string-empty-p content)
        (insert "  None.\n")
      (insert (replace-regexp-in-string "^" "  " content))
      (unless (string-suffix-p "\n" content)
        (insert "\n")))))

(defun mod-jira--insert-comments (comments)
  "Insert COMMENTS under the current issue subtree."
  (insert "** Comments\n")
  (if comments
      (dolist (comment comments)
        (insert (format "*** %s — %s\n"
                        (plist-get comment :author)
                        (or (plist-get comment :created) "")))
        (mod-jira--insert-managed-text (plist-get comment :body))
        (insert "\n"))
    (insert "  No comments.\n\n")))

(defun mod-jira--insert-issue (issue preserved-data)
  "Insert ISSUE into the current Org buffer, using PRESERVED-DATA when present."
  (let* ((key (plist-get issue :key))
         (entry (alist-get key preserved-data nil nil #'string=))
         (notes (plist-get entry :notes))
         (tags (plist-get entry :tags))
         (todo (mod-jira--todo-keyword (plist-get issue :status))))
    (insert (format "* %s %s %s%s\n"
                    todo
                    key
                    (string-trim (plist-get issue :summary))
                    (mod-jira--heading-tags-string tags)))
    (insert ":PROPERTIES:\n")
    (insert (format ":JIRA_KEY: %s\n" key))
    (insert (format ":JIRA_STATUS: %s\n" (plist-get issue :status)))
    (insert (format ":JIRA_ASSIGNEE: %s\n" (plist-get issue :assignee)))
    (insert (format ":JIRA_PRIORITY: %s\n" (plist-get issue :priority)))
    (insert (format ":JIRA_UPDATED: %s\n" (plist-get issue :updated)))
    (insert (format ":JIRA_URL: %s\n" (plist-get issue :url)))
    (insert ":END:\n")
    (insert "\n** Description\n")
    (mod-jira--insert-managed-text (plist-get issue :description))
    (insert "\n")
    (mod-jira--insert-comments (plist-get issue :comments))
    (insert "** Notes\n")
    (when (and notes (not (string-empty-p notes)))
      (insert notes)
      (unless (string-suffix-p "\n" notes)
        (insert "\n")))
    (insert "\n")))

(defun mod-jira--write-issues-file (issues)
  "Write ISSUES into the configured Jira Org file."
  (let* ((file (mod-jira--ensure-org-file))
         (directory (file-name-directory file))
         (preserved-data (mod-jira--file-heading-data)))
    (make-directory directory t)
    (with-temp-buffer
      (insert "#+title: jira\n\n")
      (insert (format "#+startup: overview\n\n"))
      (insert (format "# Synced: %s\n\n" (format-time-string "%Y-%m-%d %H:%M")))
      (dolist (issue issues)
        (mod-jira--insert-issue issue preserved-data))
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

(defun mod-jira--find-issue-heading (key)
  "Return the position of Jira issue heading KEY in the current buffer, or nil."
  (goto-char (point-min))
  (let (found)
    (org-map-entries
     (lambda ()
       (when (and (not found)
                  (string= (or (org-entry-get (point) "JIRA_KEY") "") key))
         (setq found (point))))
     nil
     'file)
    found))

(defun mod-jira-import-issue (identifier)
  "Import or update one Jira issue by IDENTIFIER."
  (interactive (list (read-string "Jira issue: ")))
  (let* ((key (mod-jira--normalize-issue-key identifier))
         (issue (mod-jira-fetch-issue key))
         (file (mod-jira--ensure-org-file)))
    (with-current-buffer (find-file-noselect file)
      (org-with-wide-buffer
        (let ((existing (mod-jira--find-issue-heading key)))
          (if existing
              (progn
                (goto-char existing)
                (let* ((preserved (mod-jira--issue-heading-data-at-point))
                     (beg (point))
                     (end (save-excursion
                            (org-end-of-subtree t t)))
                     (replacement
                      (with-temp-buffer
                        (mod-jira--insert-issue
                         issue
                         (list (cons key
                                     (list :notes (plist-get preserved :notes)
                                           :tags (plist-get preserved :tags)))))
                        (buffer-string))))
                  (delete-region beg end)
                  (goto-char beg)
                  (insert replacement)))
            (goto-char (point-max))
            (unless (bolp)
              (insert "\n"))
            (mod-jira--insert-issue issue nil)))
        (save-buffer)))
    (when (fboundp 'mod-org-refresh-agenda-files)
      (mod-org-refresh-agenda-files))
    (message "Imported Jira issue %s into %s" key file)))

(defun mod-jira--current-issue-key ()
  "Return the Jira issue key at point, or fail clearly."
  (save-excursion
    (mod-jira--goto-issue-heading)
    (or (org-entry-get (point) "JIRA_KEY")
        (user-error "Point is not inside a Jira issue subtree"))))

(defun mod-jira--confirm (action key)
  "Confirm ACTION for Jira issue KEY."
  (y-or-n-p (format "%s Jira issue %s? " action key)))

(defun mod-jira--parse-time-spent (input)
  "Parse Jira worklog INPUT like 15m, 1h, 1h30m, or 3h into seconds."
  (let* ((trimmed (downcase (replace-regexp-in-string "[[:space:]]+" "" input)))
         (matched (string-match
                   "\\`\\(?:\\([0-9]+\\)h\\)?\\(?:\\([0-9]+\\)m\\)?\\'"
                   trimmed))
         (hours (and matched
                     (match-string 1 trimmed)
                     (string-to-number (match-string 1 trimmed))))
         (minutes (and matched
                       (match-string 2 trimmed)
                       (string-to-number (match-string 2 trimmed))))
         (seconds (+ (* 3600 (or hours 0))
                     (* 60 (or minutes 0)))))
    (unless (and matched (> seconds 0))
      (user-error "Enter time like 15m, 1h, 1h30m, or 3h"))
    seconds))

(defun mod-jira--submit-worklog (key started seconds comment)
  "Submit a Jira worklog for KEY with STARTED, SECONDS, and COMMENT."
  (let* ((config (mod-jira--ensure-base-config))
         (token (plist-get config :token)))
    (mod-jira--request-data
     "POST"
     (mod-jira--issue-worklog-url key)
     token
     `((comment . ,comment)
       (started . ,started)
       (timeSpentSeconds . ,seconds))
     '(201))))

(defun mod-jira--transitions (key)
  "Return available transitions for Jira issue KEY."
  (let* ((config (mod-jira--ensure-base-config))
         (token (plist-get config :token))
         (payload (mod-jira--request-json
                   (mod-jira--issue-transitions-url key)
                   token)))
    (alist-get 'transitions payload)))

(defun mod-jira-add-comment (comment)
  "Add COMMENT to the Jira issue at point after confirmation."
  (interactive (list (read-from-minibuffer "Jira comment: ")))
  (when (string-empty-p (string-trim comment))
    (user-error "Comment text cannot be empty"))
  (let ((key (mod-jira--current-issue-key)))
    (unless (mod-jira--confirm "Add comment to" key)
      (user-error "Comment canceled"))
    (let* ((config (mod-jira--ensure-base-config))
           (token (plist-get config :token)))
      (mod-jira--request-data
       "POST"
       (mod-jira--issue-comment-url key)
       token
       `((body . ,comment))
       '(201))
      (mod-jira-refresh-issue)
      (message "Added Jira comment to %s" key))))

(defun mod-jira-transition-issue ()
  "Transition the Jira issue at point after prompting for a workflow transition."
  (interactive)
  (let* ((key (mod-jira--current-issue-key))
         (transitions (mod-jira--transitions key)))
    (unless transitions
      (user-error "No Jira transitions available for %s" key))
    (let* ((names (mapcar (lambda (transition)
                            (alist-get 'name transition))
                          transitions))
           (choice (completing-read "Jira transition: " names nil t))
           (transition
            (seq-find (lambda (item)
                        (string= (alist-get 'name item) choice))
                      transitions))
           (transition-id (alist-get 'id transition)))
      (unless transition-id
        (user-error "Could not resolve Jira transition %s" choice))
      (unless (mod-jira--confirm (format "Apply transition %s to" choice) key)
        (user-error "Transition canceled"))
      (let* ((config (mod-jira--ensure-base-config))
             (token (plist-get config :token)))
        (mod-jira--request-data
         "POST"
         (mod-jira--issue-transitions-url key)
         token
         `((transition . ((id . ,transition-id))))
         '(204))
        (mod-jira-refresh-issue)
        (message "Transitioned Jira issue %s to %s" key choice)))))

(defun mod-jira--clock-lines-in-subtree ()
  "Return closed CLOCK entries inside the current Jira issue subtree."
  (save-excursion
    (mod-jira--goto-issue-heading)
    (let ((subtree-end (save-excursion
                         (org-end-of-subtree t t)))
          (entries '()))
      (forward-line 1)
      (while (re-search-forward
              "^[ \t]*CLOCK: \\(\\[[^]]+\\]\\)--\\(\\[[^]]+\\]\\)\\(?: =>\\s-*\\([0-9]+:[0-9][0-9]\\)\\)?"
              subtree-end
              t)
        (let* ((clock-pos (line-beginning-position))
               (start-text (match-string 1))
               (end-text (match-string 2))
               (duration-text (match-string 3))
               (start-time (org-time-string-to-time start-text))
               (end-time (org-time-string-to-time end-text))
               (seconds (max 0 (round (float-time (time-subtract end-time start-time)))))
               (marker-pos (save-excursion
                             (forward-line 1)
                             (when (looking-at
                                    (format "^[ \t]*%s\\s-*\\(.+\\)$"
                                            (regexp-quote mod-jira-worklog-marker-prefix)))
                               (line-beginning-position))))
               (marker-id (save-excursion
                            (forward-line 1)
                            (when (looking-at
                                   (format "^[ \t]*%s\\s-*\\(.+\\)$"
                                           (regexp-quote mod-jira-worklog-marker-prefix)))
                              (match-string 1))))
               (summary (format "%s -> %s (%s)"
                                start-text
                                end-text
                                (or duration-text
                                    (format "%d:%02d"
                                            (/ seconds 3600)
                                            (/ (% seconds 3600) 60))))))
          (push (list :pos clock-pos
                      :start start-time
                      :start-text start-text
                      :end end-time
                      :end-text end-text
                      :seconds seconds
                      :summary summary
                      :submitted marker-id
                      :marker-pos marker-pos)
                entries)))
      (nreverse entries))))

(defun mod-jira--select-worklog-clock ()
  "Return one unsubmited Jira CLOCK entry from the current subtree."
  (let* ((entries (seq-filter (lambda (entry)
                                (not (plist-get entry :submitted)))
                              (mod-jira--clock-lines-in-subtree))))
    (unless entries
      (user-error "No unsubmitted CLOCK entry found here; clock time first"))
    (if (= (length entries) 1)
        (car entries)
      (let* ((choices (mapcar (lambda (entry)
                                (cons (plist-get entry :summary) entry))
                              entries))
             (choice (completing-read "Worklog CLOCK: " (mapcar #'car choices) nil t)))
        (alist-get choice choices nil nil #'string=)))))

(defun mod-jira--mark-clock-submitted (entry worklog-id)
  "Mark CLOCK ENTRY as submitted with WORKLOG-ID."
  (save-excursion
    (goto-char (plist-get entry :pos))
    (forward-line 1)
    (let ((line (format "%s %s\n" mod-jira-worklog-marker-prefix worklog-id)))
      (if (and (plist-get entry :marker-pos)
               (looking-at
                (format "^[ \t]*%s\\s-*\\(.+\\)$"
                        (regexp-quote mod-jira-worklog-marker-prefix))))
          (progn
            (delete-region (line-beginning-position) (line-end-position))
            (insert (string-trim-right line)))
        (insert line)))))

(defun mod-jira-log-work (comment)
  "Submit one CLOCK entry under the Jira issue at point as a Jira worklog."
  (interactive (list (read-from-minibuffer "Worklog comment: ")))
  (let* ((key (mod-jira--current-issue-key))
         (entry (mod-jira--select-worklog-clock))
         (seconds (plist-get entry :seconds))
         (started (format-time-string "%Y-%m-%dT%H:%M:%S.000%z"
                                      (plist-get entry :start))))
    (unless (> seconds 0)
      (user-error "Selected CLOCK entry has no positive duration"))
    (unless (mod-jira--confirm
             (format "Submit %s of work to" (plist-get entry :summary))
             key)
      (user-error "Worklog canceled"))
    (let* ((payload
            (mod-jira--submit-worklog key started seconds comment))
           (worklog-id (or (alist-get 'id payload) "submitted")))
      (mod-jira--mark-clock-submitted entry worklog-id)
      (save-buffer)
      (mod-jira-refresh-issue)
      (message "Submitted Jira worklog for %s" key))))

(defun mod-jira-log-work-manual (time-spent comment started-input)
  "Submit a manual Jira worklog at point.
TIME-SPENT is a Jira-style duration string, COMMENT describes the work, and
STARTED-INPUT is a date/time string understood by `org-read-date'."
  (interactive
   (list
    (read-string "Time spent (e.g. 15m, 1h30m): ")
    (read-from-minibuffer "Worklog comment: ")
    (org-read-date nil nil nil "Worklog start: "
                   nil
                   (format-time-string "%Y-%m-%d %H:%M"))))
  (let* ((key (mod-jira--current-issue-key))
         (seconds (mod-jira--parse-time-spent time-spent))
         (started-time (org-read-date nil t started-input))
         (started (format-time-string "%Y-%m-%dT%H:%M:%S.000%z" started-time)))
    (when (string-empty-p (string-trim comment))
      (user-error "Worklog comment cannot be empty"))
    (unless (mod-jira--confirm
             (format "Submit %s of manual work to" time-spent)
             key)
      (user-error "Manual worklog canceled"))
    (mod-jira--submit-worklog key started seconds comment)
    (mod-jira-refresh-issue)
    (message "Submitted manual Jira worklog for %s" key)))

(defun mod-jira-refresh-issue ()
  "Refresh only the Jira issue subtree at point."
  (interactive)
  (save-excursion
    (mod-jira--goto-issue-heading)
    (let* ((key (org-entry-get (point) "JIRA_KEY"))
           (beg (point))
           (end (save-excursion
                  (org-end-of-subtree t t)))
           (preserved (mod-jira--issue-heading-data-at-point))
           (issue (mod-jira-fetch-issue key))
           (replacement
            (with-temp-buffer
              (mod-jira--insert-issue issue
                                      (list (cons key
                                                  (list :notes (plist-get preserved :notes)
                                                        :tags (plist-get preserved :tags)))))
              (buffer-string))))
      (delete-region beg end)
      (goto-char beg)
      (insert replacement)
      (when buffer-file-name
        (save-buffer))
      (message "Refreshed Jira issue %s" key))))

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

(defun mod-jira-open-file ()
  "Open the configured Jira Org file, preferring the notes context when available."
  (interactive)
  (let ((file (mod-jira--ensure-org-file)))
    (if (fboundp 'mod-context-notes-visit-marker)
        (let ((marker
               (with-current-buffer (find-file-noselect file)
                 (copy-marker (point-min)))))
          (mod-context-notes-visit-marker marker))
      (find-file file))))

(provide 'mod-jira)

;;; mod-jira.el ends here
