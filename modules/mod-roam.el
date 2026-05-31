;;; mod-roam.el --- org-roam knowledge base -*- lexical-binding: t; -*-

(require 'cl-lib)

(declare-function org-roam-db-autosync-mode "org-roam-db")
(defun mod-roam-directory ()
  "Return the org-roam node directory."
  (or orbit-user-roam-directory
      (expand-file-name "roam/"
                        (or orbit-user-org-directory
                            (expand-file-name "org/" (getenv "HOME"))))))

(defun mod-roam--template-head (title tags)
  "Return a common org-roam file header for TITLE and TAGS."
  (format "#+title: %s\n#+filetags: %s\n#+created: %%U\n\n" title tags))

(use-package org-roam
  :ensure t
  :defer t
  :init
  (setq org-roam-directory (mod-roam-directory))
  :config
  (org-roam-db-autosync-mode 1)
  (setq org-roam-node-display-template
        (concat "${title:*} "
                (propertize "${tags:24}" 'face 'org-tag)
                (propertize "${file:36}" 'face 'shadow)))
  (setq org-roam-capture-templates
        `(("c" "concept" plain
           "* Summary\n%?\n\n* References\n\n* Related\n"
           :target (file+head "${slug}.org"
                              ,(mod-roam--template-head "${title}" ":concept:"))
           :unnarrowed t)
          ("p" "procedure" plain
           "* Purpose\n%?\n\n* Prerequisites\n\n* Steps\n\n* Expected Result\n\n* Troubleshooting\n"
           :target (file+head "procedures/${slug}.org"
                              ,(mod-roam--template-head "${title}" ":procedure:"))
           :unnarrowed t)
          ("s" "standard" plain
           "* Scope\n%?\n\n* Key Clauses\n\n* Interpretation Notes\n\n* Related Tasks / Jira\n"
           :target (file+head "standards/${slug}.org"
                              ,(mod-roam--template-head "${title}" ":standard:"))
           :unnarrowed t)
          ("m" "meeting" plain
           "* Attendees\n\n* Decisions\n\n* Actions\n%?\n"
           :target (file+head "meetings/%<%Y%m%d>-${slug}.org"
                              ,(mod-roam--template-head "${title}" ":meeting:followup:"))
           :unnarrowed t)
          ("d" "decision" plain
           "* Context\n%?\n\n* Options\n\n* Decision\n\n* Consequences\n"
           :target (file+head "decisions/${slug}.org"
                              ,(mod-roam--template-head "${title}" ":decision:"))
           :unnarrowed t)))
  (setq org-roam-dailies-directory "daily/")
  (setq org-roam-dailies-capture-templates
        '(("d" "default" entry "* %?"
           :target (file+head "%<%Y-%m-%d>.org"
                              "#+title: %<%Y-%m-%d>\n")))))

(provide 'mod-roam)

;;; mod-roam.el ends here
