;;; mod-evil.el --- Evil foundation -*- lexical-binding: t; -*-

;; `evil-collection` expects this to be set before Evil loads.
(setq evil-want-integration t
      evil-want-keybinding nil)

(use-package evil
  :ensure t
  :demand t
  :config
  (evil-mode 1))

(use-package evil-collection
  :ensure t
  :after evil
  :config
  (evil-collection-init))

(use-package evil-surround
  :ensure t
  :after evil
  :config
  (global-evil-surround-mode 1))

(use-package evil-commentary
  :ensure (:build (:not elpaca-build-compile))
  :after evil
  :config
  (evil-commentary-mode 1))

(use-package evil-args
  :ensure (:fetcher github
           :repo "wcsmith/evil-args"
           :main-file "evil-args.el")
  :after evil
  :config
  (define-key evil-inner-text-objects-map "a" #'evil-inner-arg)
  (define-key evil-outer-text-objects-map "a" #'evil-outer-arg))

(use-package evil-mc
  :ensure (:build (:not elpaca-build-compile))
  :after evil
  :config
  (global-evil-mc-mode 1))

(use-package vimish-fold
  :ensure t
  :commands (vimish-fold-mode
             vimish-fold-toggle
             vimish-fold
             vimish-fold-unfold
             vimish-fold-refold
             vimish-fold-delete))

(use-package evil-vimish-fold
  :ensure t
  :after (evil vimish-fold)
  :commands (evil-vimish-fold-mode
             evil-vimish-fold/create
             evil-vimish-fold/delete))

(provide 'mod-evil)

;;; mod-evil.el ends here
