;;; mod-markdown.el --- Markdown editing support -*- lexical-binding: t; -*-

(use-package markdown-mode
  :ensure t
  :mode (("\\.md\\'"       . gfm-mode)
         ("\\.markdown\\'" . markdown-mode)
         ("README\\.md\\'" . gfm-mode))
  :config
  (setq markdown-command
        (or (executable-find "pandoc")
            (executable-find "multimarkdown")
            "markdown"))
  (setq markdown-fontify-code-blocks-natively t)
  (setq markdown-header-scaling t)
  (setq markdown-hide-urls t))

(provide 'mod-markdown)

;;; mod-markdown.el ends here
