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

(provide 'mod-evil)

;;; mod-evil.el ends here
