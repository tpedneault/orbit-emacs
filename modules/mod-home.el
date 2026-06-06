;;; mod-home.el --- Orbit home screen via emacs-dashboard -*- lexical-binding: t; -*-

;;; Commentary:
;; Configures the `dashboard' package as the orbit-emacs home screen.
;; Projects open in the orbit edit context instead of the default switch fn.

;;; Code:

(require 'cl-lib)

(declare-function dashboard-insert-startupify-lists "dashboard")
(declare-function orbit-context-open-project-editor "orbit-context")
(defvar dashboard-buffer-name)
(defvar elpaca-after-init-hook)

(defconst mod-home-config-directory
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Root directory for this Emacs configuration.")

(defconst mod-home-buffer-name "*dashboard*"
  "Buffer used as the orbit home surface.")

(defvar mod-home--startup-dashboard-requested nil
  "Non-nil when the current startup should settle on the dashboard.")

(defvar mod-home-startup-items '((projects . 7)
                                 (recents  . 5))
  "Dashboard items rendered during initial startup.
The full dashboard item list can include slower widgets such as agenda; startup
keeps first paint focused on fast navigation targets.")

(defvar-local mod-home--startup-lightweight nil
  "Non-nil when the current dashboard buffer was rendered for startup.")

(defun mod-home--empty-startup-p ()
  "Return non-nil when Emacs was started without explicit file arguments."
  (< (length command-line-args) 2))

(defun mod-home--dashboard-buffer (&optional force-refresh startup-lightweight)
  "Render and return the Orbit dashboard buffer.
When FORCE-REFRESH is non-nil, rebuild the dashboard contents even if the
buffer already uses `dashboard-mode'.  When STARTUP-LIGHTWEIGHT is non-nil,
render only `mod-home-startup-items'."
  (if (fboundp 'dashboard-insert-startupify-lists)
      (progn
        (let ((dashboard-items (if startup-lightweight
                                   mod-home-startup-items
                                 dashboard-items)))
          (dashboard-insert-startupify-lists force-refresh))
        (when-let* ((buffer (get-buffer mod-home-buffer-name)))
          (with-current-buffer buffer
            (setq mod-home--startup-lightweight startup-lightweight))
          buffer))
    (get-buffer-create mod-home-buffer-name)))

(defun mod-home--startup-buffer ()
  "Return the dashboard buffer for empty startup, or nil for normal fallback."
  (when (mod-home--empty-startup-p)
    (setq mod-home--startup-dashboard-requested t)
    (mod-home--dashboard-buffer t t)))

(defun mod-home-open ()
  "Open the Orbit home dashboard."
  (interactive)
  (let ((buffer (mod-home--dashboard-buffer t)))
    (if (buffer-live-p buffer)
        (switch-to-buffer buffer)
      (message "orbit-home: dashboard package is not loaded"))))

(defun mod-home--open-project-in-context (root)
  "Open project ROOT in the orbit edit context rather than the default handler."
  (require 'orbit-context)
  (orbit-context-open-project-editor
   (list :root root
         :name (file-name-nondirectory (directory-file-name root)))))

(defun mod-home--refresh-visible-dashboard (&optional frame)
  "Refresh the visible dashboard in FRAME after geometry changes."
  (when-let* ((window (get-buffer-window mod-home-buffer-name frame)))
    (let ((selected-window (selected-window)))
      (with-selected-window window
        (mod-home--dashboard-buffer nil mod-home--startup-lightweight))
      (when (window-live-p selected-window)
        (select-window selected-window)))))

(defun mod-home--startup-placeholder-buffer-p (buffer)
  "Return non-nil when BUFFER is a startup placeholder we may replace."
  (not (null
        (member (buffer-name buffer)
                (list "*elpaca-log*" "*scratch*" mod-home-buffer-name)))))

(defun mod-home--refocus-after-elpaca ()
  "Show the dashboard after Elpaca releases its temporary startup buffer."
  (when (and mod-home--startup-dashboard-requested
             (mod-home--empty-startup-p)
             (not noninteractive)
             (mod-home--startup-placeholder-buffer-p (window-buffer)))
    (when-let* ((buffer (mod-home--dashboard-buffer t t)))
      (switch-to-buffer buffer))))

(use-package dashboard
  :ensure (:wait t)
  :demand t
  :init
  (setq dashboard-startup-banner
        (let ((file (expand-file-name "assets/orbit-banner.txt" mod-home-config-directory)))
          (if (file-exists-p file) file 'ascii))
        dashboard-banner-logo-title
        "orbit-emacs  ·  Modal, context-based Emacs for focused work."
        dashboard-buffer-name mod-home-buffer-name
        dashboard-startupify-list
        '(dashboard-insert-banner
          dashboard-insert-newline
          dashboard-insert-banner-title
          dashboard-insert-newline
          dashboard-insert-init-info
          dashboard-insert-newline
          dashboard-insert-newline
          dashboard-insert-items
          dashboard-insert-newline
          dashboard-insert-footer)
        dashboard-page-separator "\n\n"
        dashboard-center-content t
        dashboard-vertically-center-content nil
        dashboard-item-names
        '(("Recent Files:"     . "◈  Recent Files")
          ("Projects:"         . "◈  Projects")
          ("Agenda for today:" . "◈  Today")
          ("Bookmarks:"        . "◈  Bookmarks"))
        dashboard-projects-backend 'project-el
        dashboard-items '((projects . 7)
                          (recents  . 5))
        dashboard-path-style 'truncate-middle
        dashboard-path-max-length 58
        dashboard-shorten-by-window-width t
        dashboard-projects-show-base t
        dashboard-projects-switch-function #'mod-home--open-project-in-context
        dashboard-week-agenda nil
        dashboard-agenda-time-string-format "%m/%d"
        dashboard-agenda-prefix-format " %i %-10:c %t "
        dashboard-display-icons-p nil
        dashboard-set-heading-icons nil
        dashboard-set-file-icons nil
        dashboard-set-navigator nil
        dashboard-set-init-info t
        dashboard-footer-messages
        (list (if (mod-core-vim-profile-p)
                  "SPC h h  →  return here  ·  SPC n a  →  agenda  ·  SPC x e  →  edit context"
                "C-; h h  →  return here  ·  C-; n a  →  agenda  ·  C-; x e  →  edit context")))
  :config
  (with-eval-after-load 'mod-theme
    (custom-set-faces
     '(dashboard-banner-logo-title ((t (:inherit orbit-home-tagline :weight bold))))
     '(dashboard-heading ((t (:inherit orbit-home-section))))
     '(dashboard-items-face ((t (:inherit orbit-home-project))))
     '(dashboard-no-items-face ((t (:inherit orbit-home-todo))))
     '(dashboard-footer-face ((t (:inherit orbit-home-todo))))
     '(dashboard-text-banner ((t (:inherit orbit-home-logo))))))
  (add-hook 'dashboard-mode-hook
            (lambda ()
              (setq-local mode-line-format nil
                          header-line-format nil
                          cursor-type nil)))
  (add-hook 'window-setup-hook
            (lambda ()
              (mod-home--refresh-visible-dashboard)))
  (add-hook 'window-size-change-functions #'mod-home--refresh-visible-dashboard)
  (add-hook 'elpaca-after-init-hook #'mod-home--refocus-after-elpaca))

(setq mod-home--startup-dashboard-requested (mod-home--empty-startup-p)
      initial-buffer-choice #'mod-home--startup-buffer)

(provide 'mod-home)

;;; mod-home.el ends here
