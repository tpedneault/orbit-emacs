;;; mod-mermaid.el --- Mermaid diagram support -*- lexical-binding: t; -*-

;; ---------------------------------------------------------------------------
;; Part 1: ob-mermaid — org-babel backend for #+begin_src mermaid blocks
;; ---------------------------------------------------------------------------

(use-package ob-mermaid
  :ensure t
  :after org
  :config
  (when-let* ((mmdc (executable-find "mmdc")))
    (setq ob-mermaid-cli-path mmdc))
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages
           '((mermaid . t)))))

;; ---------------------------------------------------------------------------
;; Part 2: mermaid-mode — major mode for .mmd files
;; ---------------------------------------------------------------------------

(use-package mermaid-mode
  :ensure t
  :mode "\\.mmd\\'"
  :config
  (when-let* ((mmdc (executable-find "mmdc")))
    (setq mermaid-mmdc-location mmdc))
  (setq mermaid-output-format ".svg"))

;; ---------------------------------------------------------------------------
;; Part 3: Real-time preview
;; ---------------------------------------------------------------------------

(defvar-local mod-mermaid--last-source nil
  "Cached mermaid source for change detection in `mod-mermaid-auto-preview-mode'.")

(defvar-local mod-mermaid--idle-timer nil
  "Buffer-local handle for the auto-preview idle timer.")

(defconst mod-mermaid--preview-buffer-name "*mermaid-preview*"
  "Name of the mermaid preview side-window buffer.")

(defconst mod-mermaid--idle-delay 0.7
  "Seconds of idle time before `mod-mermaid-auto-preview-mode' re-renders.")

(defvar mod-mermaid-theme "redux-color"
  "Mermaid theme used for diagram rendering and HTML export.
Valid built-in names include: default, forest, dark, neutral, base,
redux, redux-color, redux-dark, redux-dark-color.")

(defun mod-mermaid--source-at-point ()
  "Return the mermaid source for the current context, or nil.
In `mermaid-mode': the entire buffer.
In `org-mode' inside a mermaid src block: the block body.
Otherwise: nil."
  (cond
   ((derived-mode-p 'mermaid-mode)
    (buffer-string))
   ((derived-mode-p 'org-mode)
    (let ((element (org-element-at-point)))
      (when (and (eq (org-element-type element) 'src-block)
                 (string= (org-element-property :language element) "mermaid"))
        (org-element-property :value element))))
   (t nil)))

(defun mod-mermaid--render (source callback)
  "Render mermaid SOURCE to SVG asynchronously and call CALLBACK with the output path.
CALLBACK receives the path of the generated SVG file.
The theme is taken from `mod-mermaid-theme'."
  (let* ((input-file  (make-temp-file "mermaid-in-"  nil ".mmd"))
         (output-file (make-temp-file "mermaid-out-" nil ".svg"))
         (config-file (make-temp-file "mermaid-cfg-" nil ".json"))
         (mmdc (executable-find "mmdc")))
    (unless mmdc
      (user-error "mmdc not found — install with: npm install -g @mermaid-js/mermaid-cli"))
    (write-region source nil input-file nil 'quiet)
    (write-region (format "{\"theme\":%S}" mod-mermaid-theme)
                  nil config-file nil 'quiet)
    (make-process
     :name "mod-mermaid-render"
     :buffer nil
     :command (list mmdc "-i" input-file "-o" output-file "-c" config-file)
     :sentinel (lambda (_proc event)
                 (unwind-protect
                     (if (string= (string-trim event) "finished")
                         (funcall callback output-file)
                       (message "mermaid: render failed — %s" (string-trim event)))
                   (ignore-errors (delete-file input-file))
                   (ignore-errors (delete-file config-file)))))))

(defun mod-mermaid--display-svg (svg-path)
  "Display the SVG at SVG-PATH scaled to fill the preview side window width."
  (when (file-readable-p svg-path)
    (let* ((buffer (get-buffer-create mod-mermaid--preview-buffer-name))
           ;; Ensure the window exists before reading its width so that
           ;; the image is sized to fit from the very first render.
           (window (or (get-buffer-window buffer)
                       (display-buffer
                        buffer
                        '((display-buffer-in-side-window)
                          (side . right)
                          (slot . 0)
                          (window-width . 0.4)
                          (preserve-size . (t . nil))))))
           (fit-width (and (windowp window)
                           (window-body-width window t))))
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert-image (create-image svg-path 'svg nil
                                      :width (or fit-width 600)))
          (goto-char (point-min))
          (setq buffer-read-only t))))))

(defun mod-mermaid-preview ()
  "Render the mermaid diagram at point and display it in a side window."
  (interactive)
  (let ((source (mod-mermaid--source-at-point)))
    (if source
        (mod-mermaid--render source #'mod-mermaid--display-svg)
      (user-error "No mermaid source at point (place cursor inside a mermaid src block, or use a .mmd buffer)"))))

(defun mod-mermaid--auto-preview-tick ()
  "Re-render if the mermaid source has changed since last render."
  (when (get-buffer-window mod-mermaid--preview-buffer-name)
    (let ((source (mod-mermaid--source-at-point)))
      (when (and source (not (equal source mod-mermaid--last-source)))
        (setq mod-mermaid--last-source source)
        (mod-mermaid--render source #'mod-mermaid--display-svg)))))

(define-minor-mode mod-mermaid-auto-preview-mode
  "Auto-preview mermaid diagrams in a side window while editing.
Renders the diagram after each idle pause of `mod-mermaid--idle-delay' seconds.
Only re-renders when the source has actually changed."
  :lighter " Mmmd"
  (if mod-mermaid-auto-preview-mode
      (let ((buf (current-buffer)))
        (setq mod-mermaid--last-source nil)
        (setq mod-mermaid--idle-timer
              (run-with-idle-timer
               mod-mermaid--idle-delay t
               (lambda ()
                 (when (buffer-live-p buf)
                   (with-current-buffer buf
                     (mod-mermaid--auto-preview-tick))))))
        (mod-mermaid-preview))
    (when mod-mermaid--idle-timer
      (cancel-timer mod-mermaid--idle-timer)
      (setq mod-mermaid--idle-timer nil))))

;; ---------------------------------------------------------------------------
;; Part 4: Org HTML export — render mermaid blocks as mermaid.js divs
;; ---------------------------------------------------------------------------

(with-eval-after-load 'ox-html
  (defun mod-mermaid--org-html-src-block (src-block _contents info)
    "Transcode a mermaid SRC-BLOCK to a mermaid.js div for HTML export."
    (if (string= (org-element-property :language src-block) "mermaid")
        (format "<div class=\"mermaid\">\n%s</div>"
                (org-element-property :value src-block))
      (org-export-with-backend 'html src-block _contents info)))

  (advice-add 'org-html-src-block :override #'mod-mermaid--org-html-src-block)

  (setq org-html-head-extra
        (concat org-html-head-extra
                "<script src=\"https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js\"></script>\n"
                (format "<script>mermaid.initialize({startOnLoad:true,theme:'%s'});</script>\n"
                        mod-mermaid-theme))))

(provide 'mod-mermaid)

;;; mod-mermaid.el ends here
