;;; mod-roam.el --- org-roam knowledge base -*- lexical-binding: t; -*-

(declare-function org-roam-db-autosync-mode "org-roam-db")
(defun mod-roam-directory ()
  "Return the org-roam node directory."
  (or orbit-user-roam-directory
      (expand-file-name "roam/"
                        (or orbit-user-org-directory
                            (expand-file-name "org/" (getenv "HOME"))))))

(use-package org-roam
  :ensure t
  :defer t
  :init
  (setq org-roam-directory (mod-roam-directory))
  :config
  (org-roam-db-autosync-mode 1)
  (setq org-roam-capture-templates
        '(("d" "default" plain "%?"
           :target (file+head "${slug}.org" "#+title: ${title}\n")
           :unnarrowed t)))
  (setq org-roam-dailies-directory "daily/")
  (setq org-roam-dailies-capture-templates
        '(("d" "default" entry "* %?"
           :target (file+head "%<%Y-%m-%d>.org"
                              "#+title: %<%Y-%m-%d>\n")))))

(provide 'mod-roam)

;;; mod-roam.el ends here
