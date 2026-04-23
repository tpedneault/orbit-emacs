;;; mod-completion.el --- Completion and navigation foundation -*- lexical-binding: t; -*-

(use-package vertico
  :ensure t
  :demand t
  :config
  (setq vertico-cycle t)
  (vertico-mode 1))

(use-package orderless
  :ensure t
  :demand t
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :ensure t
  :after vertico
  :config
  (marginalia-mode 1))

(use-package consult
  :ensure t
  :demand t
  :config
  ;; Keep the existing leader tree and upgrade the underlying buffer switcher.
  (global-set-key [remap switch-to-buffer] #'consult-buffer)
  (setq consult-preview-key nil)
  (when orbit-user-rg-program
    (setq consult-ripgrep-args
          (concat
           (shell-quote-argument orbit-user-rg-program)
           " --null --line-buffered --color=never --max-columns=1000"
           " --path-separator / --smart-case --no-heading --line-number ."))))

(use-package corfu
  :ensure t
  :demand t
  :config
  (setq corfu-auto nil
        corfu-cycle t
        corfu-preselect 'prompt)
  (global-corfu-mode 1))

(use-package cape
  :ensure t
  :after corfu)

(savehist-mode 1)

(provide 'mod-completion)

;;; mod-completion.el ends here
