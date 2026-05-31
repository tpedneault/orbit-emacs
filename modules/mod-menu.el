;;; mod-menu.el --- Orbit custom menu strip -*- lexical-binding: t; -*-

(require 'button)
(require 'cl-lib)
(require 'subr-x)

(declare-function mod-core-orbit-menu-enabled-p "mod-core")
(declare-function mod-keys-find-project-file "mod-keys")
(declare-function mod-keys-open-docs-directory "mod-keys")
(declare-function mod-keys-open-docs-manual "mod-keys")
(declare-function mod-keys-reload-config "mod-keys")
(declare-function mod-keys-show-jumps "mod-keys")

(defconst mod-menu--buffer-name "*Orbit Menu*"
  "Buffer name used for Orbit menu dropdowns.")

(defvar mod-menu--active-menu nil
  "Name of the currently open Orbit menu.")

(defvar mod-menu--last-source-window nil
  "Window that opened the active Orbit menu.")

(defvar mod-menu--frame nil
  "Child frame used for the active Orbit menu dropdown.")

(defvar mod-menu--previous-tab-bar-format nil
  "Tab bar format before `mod-menu-mode' enabled.")

(defvar mod-menu--previous-tab-bar-mode nil
  "Whether `tab-bar-mode' was active before `mod-menu-mode'.")

(defvar mod-menu--previous-tab-bar-lines nil
  "Selected frame tab-bar line count before `mod-menu-mode' enabled.")

(defvar mod-menu-dropdown-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "q") #'mod-menu-close)
    (define-key map (kbd "ESC") #'mod-menu-close)
    (define-key map (kbd "<escape>") #'mod-menu-close)
    (define-key map (kbd "j") #'mod-menu-next-item)
    (define-key map (kbd "k") #'mod-menu-previous-item)
    (define-key map (kbd "n") #'mod-menu-next-item)
    (define-key map (kbd "p") #'mod-menu-previous-item)
    (define-key map (kbd "<down>") #'mod-menu-next-item)
    (define-key map (kbd "<up>") #'mod-menu-previous-item)
    (define-key map (kbd "TAB") #'mod-menu-next-item)
    (define-key map (kbd "<tab>") #'mod-menu-next-item)
    (define-key map (kbd "<backtab>") #'mod-menu-previous-item)
    (define-key map (kbd "RET") #'mod-menu-activate-item)
    (define-key map (kbd "<return>") #'mod-menu-activate-item)
    map)
  "Keymap for Orbit menu dropdown buffers.")

(define-derived-mode mod-menu-dropdown-mode special-mode "Orbit-Menu"
  "Major mode for Orbit menu dropdown buffers."
  (setq-local cursor-type nil
              mode-line-format nil
              header-line-format nil
              truncate-lines t
              display-line-numbers nil)
  (when (fboundp 'display-line-numbers-mode)
    (display-line-numbers-mode -1))
  (setq-local face-remapping-alist '((default orbit-menu-dropdown))))

(defconst mod-menu--menus
  '((:name "File"
     :items ((:label "Find File Anywhere" :command find-file :key "C-; ,")
             (:label "Find Project File" :command mod-keys-find-project-file :key "C-; .")
             (:label "Recent Files" :command mod-core-recentf-open :key "C-; f r")
             (:label "Open Path" :command orbit-context-open-path :key "C-; f f")
             (:label "Open At Point" :command mod-core-open-at-point :key "C-; f o")
             (:label "Save Buffer" :command save-buffer :key "C-; f s")
             (:label "Reload Config" :command mod-keys-reload-config :key "C-; f c r")))
    (:name "Edit"
     :items ((:label "Undo" :command undo :key "C-/")
             (:label "Redo" :command undo-redo :key "C-?")
             (:label "Duplicate Line/Region" :command mod-core-duplicate-line-or-region :key "C-; c d")
             (:label "Expand Region" :command er/expand-region :key "C-; v")
             (:heading "Copy Path")
             (:label "Absolute File Path" :command mod-core-copy-absolute-file-path :key "C-; f y a")
             (:label "Project Relative Path" :command mod-core-copy-project-relative-file-path :key "C-; f y r")
             (:label "Directory Path" :command mod-core-copy-directory-path :key "C-; f y d")))
    (:name "Buffers"
     :items ((:label "Switch Buffer" :command consult-buffer :key "C-; SPC")
             (:label "Kill Current Buffer" :command kill-current-buffer :key "C-; b d")
             (:label "Next Buffer" :command next-buffer :key "C-; b n")
             (:label "Previous Buffer" :command previous-buffer :key "C-; b p")
             (:label "Revert Buffer" :command revert-buffer :key "C-; b r")))
    (:name "Project"
     :items ((:label "Switch Project Context" :command mod-project-switch :key "C-; p p")
             (:label "Add Project" :command mod-project-add :key "C-; p a")
             (:label "Forget Project" :command mod-project-forget :key "C-; p d")
             (:label "Find Project File" :command project-find-file :key "C-; p f")
             (:label "Search Project" :command mod-project-search :key "C-; p s")
             (:label "Replace In Project" :command mod-project-replace :key "C-; p R")))
    (:name "Search"
     :items ((:label "Project Search" :command mod-search-project :key "C-; s s")
             (:label "Buffer Search" :command mod-search-buffer :key "C-; s b")
             (:label "Directory Search" :command mod-search-directory :key "C-; s d")
             (:label "Find Project Files" :command mod-search-project-files :key "C-; s f")
             (:label "Imenu" :command consult-imenu :key "C-; s i")
             (:label "Outline" :command consult-outline :key "C-; s o")
             (:label "Marks/Jumps" :command mod-keys-show-jumps :key "C-; s j")))
    (:name "Git"
     :items ((:label "Status" :command mod-git-status :key "C-; g g")
             (:label "Log" :command mod-git-log :key "C-; g l")
             (:label "Blame" :command mod-git-blame :key "C-; g b")
             (:label "Diff" :command magit-diff :key "C-; g D")
             (:label "File Log" :command mod-git-log-file :key "C-; g L")
             (:label "Stage File" :command mod-git-stage-file :key "C-; g S")
             (:label "Unstage File" :command mod-git-unstage-file :key "C-; g U")
             (:heading "Hunks")
             (:label "Next Hunk" :command diff-hl-next-hunk :key "C-; g ]")
             (:label "Previous Hunk" :command diff-hl-previous-hunk :key "C-; g [")
             (:label "Revert Hunk" :command diff-hl-revert-hunk :key "C-; g r")
             (:label "Git Time Machine" :command git-timemachine :key "C-; g t")
             (:label "Forge Merge Requests" :command forge-list-pullreqs :key "C-; g F")))
    (:name "Contexts"
     :items ((:label "Context Panel" :command orbit-context-dispatch :key "C-; x .")
             (:label "Switch Context" :command orbit-context-switch :key "C-; x x")
             (:label "New Context" :command orbit-context-new :key "C-; x n")
             (:label "Delete Context" :command orbit-context-delete :key "C-; x d")
             (:label "Rename Context" :command orbit-context-rename :key "C-; x r")
             (:heading "Open")
             (:label "Edit Context" :command orbit-context-editor :key "C-; x e")
             (:label "Git Context" :command orbit-context-git :key "C-; x g")
             (:label "Files Context" :command orbit-context-files :key "C-; x f")
             (:label "Notes Context" :command orbit-context-notes :key "C-; x o")
             (:label "Agenda Context" :command orbit-context-agenda :key "C-; x a")
             (:label "Scratch Context" :command orbit-context-scratch :key "C-; x s")
             (:heading "Navigate")
             (:label "Previous Context" :command orbit-context-previous :key "C-; x [")
             (:label "Next Context" :command orbit-context-next :key "C-; x ]")
             (:label "Project Suite" :command orbit-context-project-suite :key "C-; x p")
             (:label "Related Context" :command orbit-context-related :key "C-; x R")))
    (:name "Notes"
     :items ((:label "Open Notes" :command mod-org-open-notes :key "C-; n n")
             (:label "Open Agenda" :command mod-org-open-agenda :key "C-; n a")
             (:label "Capture" :command mod-org-capture :key "C-; n C")
             (:label "Inbox Task" :command mod-org-capture-inbox-task :key "C-; n t")
             (:label "Quick Note" :command mod-org-capture-note :key "C-; n N")
             (:label "Journal" :command mod-org-capture-journal :key "C-; n j j")
             (:heading "Roam")
             (:label "Find Node" :command org-roam-node-find :key "C-; n r f")
             (:label "Insert Link" :command org-roam-node-insert :key "C-; n r i")
             (:label "Backlinks" :command org-roam-buffer-toggle :key "C-; n r b")
             (:label "Today" :command org-roam-dailies-goto-today :key "C-; n r d")
             (:label "Pick Date" :command org-roam-dailies-find-date :key "C-; n r D")
             (:label "Sync DB" :command org-roam-db-sync :key "C-; n r s")
             (:heading "Jira")
             (:label "Open Jira File" :command mod-jira-open-file :key "C-; n j J")
             (:label "Sync Jira" :command mod-jira-sync :key "C-; n j s")
             (:label "Open Issue" :command mod-jira-open-issue :key "C-; n j o")
             (:label "Log Work" :command mod-jira-log-work :key "C-; n j w")))
    (:name "Tools"
     :items ((:label "Project Tree" :command mod-dired-project-sidebar-toggle :key "C-; o p")
             (:label "Shell" :command mod-shell-open :key "C-; o s")
             (:label "New Shell" :command mod-shell-new :key "C-; o S")
             (:label "Messages" :command mod-utility-messages :key "C-; o m")
             (:label "Help Buffer" :command mod-utility-help :key "C-; o h")
             (:label "Compilation" :command mod-utility-compilation :key "C-; o c")))
    (:name "View"
     :items ((:label "Fullscreen" :command mod-ui-toggle-fullscreen :key "C-; t f")
             (:label "Big Font" :command mod-ui-toggle-big-font :key "C-; t b")
             (:label "Line Numbers" :command mod-ui-toggle-line-numbers :key "C-; t l")
             (:label "Line Number Style" :command mod-ui-toggle-line-number-style :key "C-; t L")
             (:label "Fill Column" :command mod-ui-toggle-fill-column-indicator :key "C-; t c")
             (:label "Highlight Line" :command mod-ui-toggle-hl-line :key "C-; t h")
             (:label "Whitespace" :command mod-ui-toggle-whitespace :key "C-; t s")
             (:label "Wrap" :command mod-ui-toggle-wrap :key "C-; t w")
             (:label "Modeline" :command mod-ui-toggle-modeline :key "C-; t m")
             (:label "Choose Theme" :command mod-theme-select :key "C-; t T")))
    (:name "Help"
     :items ((:label "Orbit Home" :command mod-home-open :key "C-; h h")
             (:label "Docs Manual" :command mod-keys-open-docs-manual :key "C-; h d")
             (:label "Docs Directory" :command mod-keys-open-docs-directory :key "C-; h D")
             (:label "Describe Key" :command describe-key :key "C-; h k")
             (:label "Describe Function" :command describe-function :key "C-; h f")
             (:label "Describe Variable" :command describe-variable :key "C-; h v")
             (:label "Describe Mode" :command describe-mode :key "C-; h m"))))
  "Data used to render the custom Orbit menu.")

(defun mod-menu--menu-names ()
  "Return top-level Orbit menu names."
  (mapcar (lambda (menu) (plist-get menu :name)) mod-menu--menus))

(defun mod-menu--find-menu (name)
  "Return the menu plist called NAME."
  (cl-find name mod-menu--menus :key (lambda (menu) (plist-get menu :name)) :test #'equal))

(defun mod-menu--enabled-p ()
  "Return non-nil when the Orbit menu strip should be rendered."
  (and (fboundp 'mod-core-orbit-menu-enabled-p)
       (mod-core-orbit-menu-enabled-p)))

(defun mod-menu--bar-visible-p ()
  "Return non-nil when the current frame should show the menu strip."
  (and (mod-menu--enabled-p)
       (not (frame-parameter nil 'mod-menu-dropdown-frame))
       (not (minibufferp (window-buffer (selected-window))))))

(defun mod-menu--open-from-tab-bar (name)
  "Open Orbit menu NAME from a tab-bar click."
  (interactive)
  (mod-menu-open name (and (eventp last-input-event) last-input-event)))

(defun mod-menu--tab-item (name index)
  "Return a clickable tab-bar item for menu NAME at INDEX."
  (let* ((active (equal name mod-menu--active-menu))
         (face (if active 'orbit-menu-label-active 'orbit-menu-label))
         (label (propertize
                 (concat " " name " ")
                 'face face
                 'mouse-face 'orbit-menu-label-active))
         (command `(lambda ()
                     (interactive)
                     (mod-menu--open-from-tab-bar ,name))))
    `((,(intern (format "orbit-menu-%d" index))
       menu-item ,label ,command
       :help ,(format "Open %s menu" name)))))

(defun mod-menu-bar-format ()
  "Return the Orbit tab-bar menu format for the selected frame."
  (when (mod-menu--bar-visible-p)
    (append
     `((orbit-menu-brand
        menu-item ,(propertize " ORBIT " 'face 'orbit-menu-strip) ignore))
     (cl-loop for name in (mod-menu--menu-names)
              for index from 1
              append `((,(intern (format "orbit-menu-sep-%d" index))
                        menu-item ,(propertize " " 'face 'orbit-menu-strip) ignore))
              append (mod-menu--tab-item name index))
     `((orbit-menu-fill
        menu-item ,(propertize " "
                               'display '(space :align-to right)
                               'face 'orbit-menu-strip)
        ignore)))))

(defun mod-menu--ensure-frame (&optional frame)
  "Ensure FRAME is showing the Orbit menu tab bar when appropriate."
  (when (and mod-menu-mode
             (mod-menu--enabled-p)
             (not (frame-parameter frame 'mod-menu-dropdown-frame)))
    (with-selected-frame (or frame (selected-frame))
      (setq tab-bar-format '(mod-menu-bar-format))
      (set-frame-parameter nil 'tab-bar-lines 1)
      (unless (bound-and-true-p tab-bar-mode)
        (tab-bar-mode 1))
      (force-mode-line-update t))))

(defun mod-menu--command-available-p (command)
  "Return non-nil when COMMAND can be executed."
  (and command (commandp command)))

(defun mod-menu--item-enabled-p (item)
  "Return non-nil when ITEM should be active."
  (mod-menu--command-available-p (plist-get item :command)))

(defun mod-menu--item-key (item)
  "Return ITEM key hint, or nil."
  (when orbit-menu-show-key-hints
    (plist-get item :key)))

(defun mod-menu--item-action (button)
  "Run the command attached to BUTTON."
  (let ((command (button-get button 'mod-menu-command)))
    (mod-menu-close)
    (when (commandp command)
      (call-interactively command))))

(defun mod-menu--insert-heading (label)
  "Insert dropdown heading LABEL."
  (insert (propertize (format "\n  %s\n" label) 'face 'orbit-menu-dropdown-heading)))

(defun mod-menu--insert-command (item width)
  "Insert one command ITEM padded to WIDTH."
  (let* ((label (plist-get item :label))
         (key (mod-menu--item-key item))
         (command (plist-get item :command))
         (enabled (mod-menu--item-enabled-p item))
         (face (if enabled 'orbit-menu-dropdown-command 'orbit-menu-dropdown-disabled))
         (row-label (format (format "  %%-%ds" width) label))
         (row-key (if key (format " %s" key) "")))
    (if enabled
        (insert-text-button
         (concat row-label row-key)
         'face face
         'follow-link t
         'help-echo (format "Run %s" label)
         'mod-menu-command command
         'action #'mod-menu--item-action)
      (insert (propertize (concat row-label row-key) 'face face)))
    (insert "\n")))

(defun mod-menu--command-width (items)
  "Return label width for command ITEMS."
  (max 18
       (cl-loop for item in items
                when (plist-get item :label)
                maximize (string-width (plist-get item :label)))))

(defun mod-menu--populate-buffer (menu)
  "Populate the current dropdown buffer from MENU."
  (let* ((items (plist-get menu :items))
         (width (mod-menu--command-width items))
         (inhibit-read-only t))
    (erase-buffer)
    (insert (propertize (format "  %s\n" (plist-get menu :name))
                        'face 'orbit-menu-dropdown-title))
    (dolist (item items)
      (if-let* ((heading (plist-get item :heading)))
          (mod-menu--insert-heading heading)
        (mod-menu--insert-command item width)))
    (goto-char (point-min))
    (mod-menu-next-item)))

(defun mod-menu--buffer-size (buffer)
  "Return practical frame size for dropdown BUFFER as (WIDTH . HEIGHT)."
  (with-current-buffer buffer
    (let ((width 24)
          (height 0))
      (save-excursion
        (goto-char (point-min))
        (while (not (eobp))
          (setq width (max width (string-width
                                  (buffer-substring-no-properties
                                   (line-beginning-position)
                                   (line-end-position)))))
          (setq height (1+ height))
          (forward-line 1)))
      (cons (+ width 2)
            (min (max 4 height)
                 (max 6 (or orbit-menu-dropdown-height 14)))))))

(defun mod-menu--event-frame-position (event)
  "Return child-frame pixel position for dropdown opened by EVENT."
  (when event
    (let* ((start (event-start event))
           (window (posn-window start))
           (xy (posn-x-y start)))
      (when (consp xy)
        (if (windowp window)
            (cons (+ (window-pixel-left window) (car xy))
                  (+ (window-pixel-top window)
                     (cdr xy)
                     (frame-char-height)))
          (cons (car xy) (frame-char-height)))))))

(defun mod-menu--display-child-frame (buffer event)
  "Display BUFFER in an Orbit-styled child frame under EVENT."
  (let* ((size (mod-menu--buffer-size buffer))
         (position (or (mod-menu--event-frame-position event) (cons 0 (frame-char-height))))
         (parent (selected-frame))
         (font (frame-parameter parent 'font))
         (frame (make-frame
                 `((parent-frame . ,parent)
                   ,@(when font `((font . ,font)))
                   (minibuffer . nil)
                   (undecorated . t)
                   (no-special-glyphs . t)
                   (skip-taskbar . t)
                   (no-other-frame . t)
                   (unsplittable . t)
                   (visibility . nil)
                   (left . ,(car position))
                   (top . ,(cdr position))
                   (width . ,(car size))
                   (height . ,(cdr size))
                   (internal-border-width . 1)
                   (border-width . 0)
                   (vertical-scroll-bars . nil)
                   (horizontal-scroll-bars . nil)
                   (menu-bar-lines . 0)
                   (tab-bar-lines . 0)
                   (tool-bar-lines . 0)
                   (line-spacing . 0)
                   (mod-menu-dropdown-frame . t)
                   (desktop-dont-save . t)))))
    (setq mod-menu--frame frame)
    (with-selected-frame frame
      (switch-to-buffer buffer)
      (when-let* ((border-color (face-background 'orbit-menu-label-active nil t)))
        (set-face-background 'internal-border border-color frame))
      (set-frame-parameter frame 'background-color
                           (or (face-background 'orbit-menu-dropdown nil t)
                               (face-background 'default nil t)))
      (set-frame-parameter frame 'foreground-color
                           (or (face-foreground 'orbit-menu-dropdown nil t)
                               (face-foreground 'default nil t)))
      (make-frame-visible frame)
      (select-frame-set-input-focus frame))
    frame))

(defun mod-menu--display-buffer (buffer)
  "Display dropdown BUFFER in a top side window."
  (display-buffer-in-side-window
   buffer
   `((side . top)
     (slot . -1)
     (window-height . ,(max 6 (or orbit-menu-dropdown-height 14)))
     (window-parameters . ((no-other-window . t)
                           (no-delete-other-windows . t))))))

(defun mod-menu-open (name &optional event)
  "Open Orbit menu NAME."
  (interactive
   (list (completing-read "Orbit menu: " (mod-menu--menu-names) nil t)))
  (let ((menu (mod-menu--find-menu name)))
    (unless menu
      (user-error "No Orbit menu named %s" name))
    (setq mod-menu--active-menu name
          mod-menu--last-source-window (selected-window))
    (let ((buffer (get-buffer-create mod-menu--buffer-name)))
      (with-current-buffer buffer
        (mod-menu-dropdown-mode)
        (mod-menu--populate-buffer menu))
      (if (display-graphic-p)
          (progn
            (when (frame-live-p mod-menu--frame)
              (delete-frame mod-menu--frame))
            (mod-menu--display-child-frame buffer event))
        (select-window (mod-menu--display-buffer buffer))))
    (force-mode-line-update t)))

(defun mod-menu-close ()
  "Close the active Orbit menu dropdown."
  (interactive)
  (when (frame-live-p mod-menu--frame)
    (delete-frame mod-menu--frame))
  (setq mod-menu--frame nil)
  (let ((buffer (get-buffer mod-menu--buffer-name)))
    (when (and buffer (get-buffer-window buffer t))
      (delete-window (get-buffer-window buffer t))))
  (setq mod-menu--active-menu nil)
  (when (window-live-p mod-menu--last-source-window)
    (select-window mod-menu--last-source-window))
  (setq mod-menu--last-source-window nil)
  (force-mode-line-update t))

(defun mod-menu-next-item ()
  "Move to the next active command in an Orbit menu."
  (interactive)
  (condition-case nil
      (forward-button 1 t)
    (error (goto-char (point-min))
           (forward-button 1 t))))

(defun mod-menu-previous-item ()
  "Move to the previous active command in an Orbit menu."
  (interactive)
  (condition-case nil
      (backward-button 1 t)
    (error (goto-char (point-max))
           (backward-button 1 t))))

(defun mod-menu-activate-item ()
  "Activate the command button at point."
  (interactive)
  (if-let* ((button (button-at (point))))
      (push-button (point))
    (mod-menu-next-item)
    (when (button-at (point))
      (push-button (point)))))

(define-minor-mode mod-menu-mode
  "Global mode for the Orbit custom menu strip."
  :global t
  :lighter nil
  (if mod-menu-mode
      (progn
        (setq mod-menu--previous-tab-bar-format tab-bar-format
              mod-menu--previous-tab-bar-mode (bound-and-true-p tab-bar-mode)
              mod-menu--previous-tab-bar-lines (frame-parameter nil 'tab-bar-lines)
              tab-bar-format '(mod-menu-bar-format))
        (add-hook 'buffer-list-update-hook #'mod-menu--ensure-frame)
        (add-hook 'window-configuration-change-hook #'mod-menu--ensure-frame)
        (add-hook 'find-file-hook #'mod-menu--ensure-frame)
        (add-hook 'after-make-frame-functions #'mod-menu--ensure-frame)
        (mod-menu--ensure-frame))
    (mod-menu-close)
    (remove-hook 'buffer-list-update-hook #'mod-menu--ensure-frame)
    (remove-hook 'window-configuration-change-hook #'mod-menu--ensure-frame)
    (remove-hook 'find-file-hook #'mod-menu--ensure-frame)
    (remove-hook 'after-make-frame-functions #'mod-menu--ensure-frame)
    (setq tab-bar-format mod-menu--previous-tab-bar-format)
    (set-frame-parameter nil 'tab-bar-lines mod-menu--previous-tab-bar-lines)
    (unless mod-menu--previous-tab-bar-mode
      (tab-bar-mode -1))))

(when (mod-menu--enabled-p)
  (mod-menu-mode 1))

(provide 'mod-menu)

;;; mod-menu.el ends here
