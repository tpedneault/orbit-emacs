;;; mod-python.el --- Minimal Python development support -*- lexical-binding: t; -*-

(require 'compile)
(require 'project)
(require 'python)
(require 'seq)
(require 'subr-x)
(require 'xref)

(autoload 'dape "dape" nil t)
(autoload 'dape-breakpoint-toggle "dape" nil t)
(autoload 'dape-breakpoint-remove-at-point "dape" nil t)
(autoload 'dape-breakpoint-remove-all "dape" nil t)
(autoload 'dape-breakpoint-expression "dape" nil t)
(autoload 'dape-breakpoint-log "dape" nil t)
(autoload 'dape-breakpoint-function "dape" nil t)
(autoload 'dape-watch-dwim "dape" nil t)
(autoload 'dape-next "dape" nil t)
(autoload 'dape-step-in "dape" nil t)
(autoload 'dape-step-out "dape" nil t)
(autoload 'dape-continue "dape" nil t)
(autoload 'dape-pause "dape" nil t)
(autoload 'dape-restart "dape" nil t)
(autoload 'dape-kill "dape" nil t)
(autoload 'dape-repl "dape" nil t)
(autoload 'dape-info "dape" nil t)

(declare-function dape "dape" (config &optional skip-compile))
(declare-function dape-breakpoint-toggle "dape" ())
(declare-function dape-breakpoint-remove-at-point "dape" (&optional skip-notify))
(declare-function dape-breakpoint-remove-all "dape" ())
(declare-function dape-breakpoint-expression "dape" (expression))
(declare-function dape-breakpoint-log "dape" (message))
(declare-function dape-breakpoint-function "dape" (name))
(declare-function dape-watch-dwim "dape" (expression &optional remove-only-p add-only-p display-p))
(declare-function dape-next "dape" (conn))
(declare-function dape-step-in "dape" (conn))
(declare-function dape-step-out "dape" (conn))
(declare-function dape-continue "dape" (conn))
(declare-function dape-pause "dape" (conn))
(declare-function dape-restart "dape" (&optional conn skip-compile))
(declare-function dape-kill "dape" (conn &optional cb with-disconnect))
(declare-function dape-repl "dape" ())
(declare-function dape-info "dape" (&optional maybe-kill))
(declare-function evil-define-minor-mode-key "evil-core" (state mode &rest bindings))
(declare-function eglot-alternatives "eglot" (alternatives))
(declare-function eglot-ensure "eglot" ())
(declare-function eglot-format-buffer "eglot" ())
(declare-function eglot-managed-p "eglot" ())
(declare-function eglot-rename "eglot" (newname))
(declare-function eglot-reconnect "eglot" (server))

(defgroup mod-python nil
  "Minimal Python development helpers."
  :group 'tools)

(defconst mod-python-language-server-candidates
  '(("basedpyright-langserver" "--stdio")
    ("pyright-langserver" "--stdio"))
  "Preferred Python language server commands for Eglot.")

(defconst mod-python-venv-directory-names '(".venv" "venv")
  "Project-local virtual environment directory names to detect.")

(defconst mod-python-project-root-markers
  '("pyproject.toml" "setup.py" "setup.cfg" ".git")
  "Files or directories that identify a practical Python project root.")

(defconst mod-python-uv-project-markers
  '("pyproject.toml" "uv.lock" ".venv" "venv")
  "Files or directories that identify a practical uv-managed Python project.")

(defconst mod-python-buffer-name-prefix "*python:"
  "Prefix used for Python helper buffers.")

(defvar-local mod-python-last-run-args ""
  "Last argument string used for Python run commands in the current buffer.")

(defvar-local mod-python-last-debug-args ""
  "Last argument string used for Python debug commands in the current buffer.")

(defvar mod-python-debugger-keys-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "c") #'dape-continue)
    (define-key map (kbd "n") #'dape-next)
    (define-key map (kbd "i") #'dape-step-in)
    (define-key map (kbd "o") #'dape-step-out)
    (define-key map (kbd "p") #'dape-pause)
    (define-key map (kbd "r") #'dape-restart)
    (define-key map (kbd "q") #'dape-kill)
    (define-key map (kbd "b") #'dape-breakpoint-toggle)
    (define-key map (kbd "x") #'dape-breakpoint-remove-at-point)
    (define-key map (kbd "w") #'dape-watch-dwim)
    (define-key map (kbd "R") #'dape-repl)
    (define-key map (kbd "I") #'dape-info)
    map)
  "Transient single-key debugger controls for active Python debug sessions.")

(define-minor-mode mod-python-debugger-keys-mode
  "Enable short single-key debugger controls in Python source buffers."
  :init-value nil
  :lighter nil
  :keymap mod-python-debugger-keys-mode-map)

(defun mod-python--root-search-directory ()
  "Return the directory to use when searching for a Python project root."
  (or (and buffer-file-name
           (file-name-directory buffer-file-name))
      default-directory))

(defun mod-python--dape-session-active-p ()
  "Return non-nil when Dape currently has a live session."
  (and (boundp 'dape--connections)
       dape--connections))

(defun mod-python--python-buffer-p (&optional buffer)
  "Return non-nil when BUFFER is a Python editing buffer."
  (with-current-buffer (or buffer (current-buffer))
    (derived-mode-p 'python-base-mode)))

(defun mod-python--sync-debugger-keys-buffer (&optional buffer)
  "Enable or disable short debugger keys in BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (when (mod-python--python-buffer-p)
      (mod-python-debugger-keys-mode
       (if (mod-python--dape-session-active-p) 1 -1)))))

(defun mod-python--refresh-debugger-key-buffers ()
  "Refresh short debugger keys across live Python buffers."
  (dolist (buffer (buffer-list))
    (mod-python--sync-debugger-keys-buffer buffer)))

(defun mod-python-project-root ()
  "Return the current project root, or nil outside a project."
  (or (when-let* ((project (project-current nil)))
        (project-root project))
      (when-let* ((directory (mod-python--root-search-directory)))
        (seq-some
         (lambda (marker)
           (locate-dominating-file directory marker))
         (append mod-python-project-root-markers
                 mod-python-venv-directory-names)))))

(defun mod-python--working-directory ()
  "Return the preferred working directory for the current Python buffer."
  (or (mod-python-project-root)
      (and buffer-file-name (file-name-directory buffer-file-name))
      default-directory))

(defun mod-python--venv-root ()
  "Return the detected project-local virtualenv root, or nil."
  (when-let* ((root (mod-python-project-root)))
    (seq-find
     #'file-directory-p
     (mapcar (lambda (name)
               (expand-file-name name root))
             mod-python-venv-directory-names))))

(defun mod-python--venv-bin-directory ()
  "Return the executable directory for the detected virtualenv, or nil."
  (when-let* ((venv-root (mod-python--venv-root)))
    (expand-file-name
     (if (eq system-type 'windows-nt) "Scripts/" "bin/")
     venv-root)))

(defun mod-python--venv-executable (name)
  "Return executable NAME from the detected virtualenv, or nil."
  (when-let* ((bin-dir (mod-python--venv-bin-directory)))
    (let* ((base (if (and (eq system-type 'windows-nt)
                          (not (string-suffix-p ".exe" name)))
                     (concat name ".exe")
                   name))
           (path (expand-file-name base bin-dir)))
      (when (file-executable-p path)
        path))))

(defun mod-python--executable (names)
  "Return the first available executable from NAMES.
Prefer project-local virtualenv executables before PATH lookup."
  (seq-some
   (lambda (name)
     (or (mod-python--venv-executable name)
         (executable-find name)))
   names))

(defun mod-python-venv-python ()
  "Return the detected project-local virtualenv Python, or nil."
  (mod-python--venv-executable "python3"))

(defun mod-python--python-executable ()
  "Return the preferred Python interpreter path, or signal a clear error."
  (or (mod-python-venv-python)
      (mod-python--executable '("python3" "python"))
      (user-error "No Python interpreter found (install python3 or python)")))

(defun mod-python--language-server-available-p ()
  "Return non-nil when a preferred Python language server is available."
  (seq-some
   (lambda (candidate)
     (mod-python--executable (list (car candidate))))
   mod-python-language-server-candidates))

(defun mod-python--module-name ()
  "Return a practical Python module name for the current file, or nil."
  (when-let* ((file buffer-file-name)
              (root (mod-python-project-root))
              ((string-prefix-p (file-truename root)
                                (file-truename file))))
    (let* ((relative (file-relative-name file root))
           (sans-ext (string-remove-suffix ".py" relative))
           (module (replace-regexp-in-string "/" "." sans-ext)))
      (unless (string-empty-p module)
        (string-remove-suffix ".__init__" module)))))

(defun mod-python-use-uv-p ()
  "Return non-nil when the current Python buffer should run with uv."
  (and (executable-find "uv")
       (when-let* ((root (mod-python-project-root)))
         (seq-some
          (lambda (marker)
            (file-exists-p (expand-file-name marker root)))
          mod-python-uv-project-markers))))

(defun mod-python-read-args (prompt &optional variable)
  "Read shell-style arguments with PROMPT and remember them in VARIABLE.
Return a list of arguments parsed with `split-string-and-unquote'."
  (let* ((storage (or variable 'mod-python-last-run-args))
         (initial (or (and (local-variable-p storage)
                           (symbol-value storage))
                      ""))
         (raw (read-string prompt initial)))
    (set (make-local-variable storage) raw)
    (if (string-empty-p (string-trim raw))
        nil
      (split-string-and-unquote raw))))

(defun mod-python--shell-command (parts)
  "Return a shell command string from PARTS."
  (string-join (mapcar #'shell-quote-argument parts) " "))

(defun mod-python--run-command-prefix ()
  "Return the command prefix for Python run commands."
  (if (mod-python-use-uv-p)
      (list "uv" "run" "python")
    (list (mod-python--python-executable))))

(defun mod-python--configure-environment ()
  "Configure a project-local Python environment for the current buffer."
  (when-let* ((bin-dir (mod-python--venv-bin-directory)))
    (setq-local exec-path (cons bin-dir (delete bin-dir exec-path)))
    (setq-local process-environment (copy-sequence process-environment))
    (setenv "PATH" (concat bin-dir path-separator (or (getenv "PATH") "")))
    (when-let* ((venv-root (mod-python--venv-root)))
      (setenv "VIRTUAL_ENV" venv-root))
    (setq-local python-shell-interpreter (mod-python--python-executable))))

(defun mod-python--maybe-start-eglot ()
  "Start Eglot in the current Python buffer when a server is available."
  (when (and buffer-file-name
             (mod-python--language-server-available-p))
    (eglot-ensure)))

(defun mod-python-setup ()
  "Apply minimal Python development defaults to the current buffer."
  (mod-python--configure-environment)
  (mod-python--sync-debugger-keys-buffer)
  (mod-python--maybe-start-eglot))

(defun mod-python-eglot ()
  "Start or ensure Eglot in the current Python buffer."
  (interactive)
  (unless (mod-python--language-server-available-p)
    (user-error "No Python language server found (install basedpyright or pyright)"))
  (eglot-ensure))

(defun mod-python-eglot-reconnect ()
  "Reconnect the active Python Eglot session, or start one when missing."
  (interactive)
  (if (and (fboundp 'eglot-managed-p)
           (eglot-managed-p))
      (eglot-reconnect (eglot-managed-p))
    (mod-python-eglot)))

(defun mod-python-show-docs ()
  "Show documentation for the symbol at point."
  (interactive)
  (call-interactively #'eldoc-doc-buffer))

(defun mod-python-format-buffer ()
  "Format the current Python buffer with ruff or black."
  (interactive)
  (unless buffer-file-name
    (user-error "Current Python buffer is not visiting a file"))
  (let* ((formatter
          (or (when-let* ((ruff (mod-python--executable '("ruff"))))
                (list ruff "format"))
              (when-let* ((black (mod-python--executable '("black"))))
                (list black "-q"))
              (user-error "No Python formatter found (install ruff or black)")))
         (program (car formatter))
         (args (append (cdr formatter) (list buffer-file-name))))
    (save-buffer)
    (with-temp-buffer
      (let ((status (apply #'process-file program nil t nil args)))
        (unless (zerop status)
          (user-error "Python formatter failed: %s"
                      (string-trim (buffer-substring-no-properties
                                    (point-min)
                                    (point-max)))))))
    (revert-buffer :ignore-auto :noconfirm)
    (message "Formatted %s" (file-name-nondirectory buffer-file-name))))

(defun mod-python--compile (command)
  "Run COMMAND from the current Python working directory."
  (let ((default-directory (mod-python--working-directory)))
    (compile command)))

(defun mod-python-run-file (args)
  "Run the current Python file with ARGS."
  (interactive
   (list (mod-python-read-args "Python file args: " 'mod-python-last-run-args)))
  (unless buffer-file-name
    (user-error "Current Python buffer is not visiting a file"))
  (save-buffer)
  (mod-python--compile
   (mod-python--shell-command
    (append (mod-python--run-command-prefix)
            (list buffer-file-name)
            args))))

(defun mod-python-run-module (module args)
  "Run Python MODULE from the current project or buffer directory with ARGS."
  (interactive
   (list
    (read-string "Python module: "
                 (or (mod-python--module-name) ""))
    (mod-python-read-args "Python module args: " 'mod-python-last-run-args)))
  (when (string-empty-p (string-trim module))
    (user-error "Python module cannot be empty"))
  (save-buffer)
  (mod-python--compile
   (mod-python--shell-command
    (append (mod-python--run-command-prefix)
            (list "-m" module)
            args))))

(defun mod-python-debug-file (args)
  "Start a debugpy Dape session for the current Python file with ARGS."
  (interactive
   (list (mod-python-read-args "Python debug args: " 'mod-python-last-debug-args)))
  (unless buffer-file-name
    (user-error "Current Python buffer is not visiting a file"))
  (unless (require 'dape nil t)
    (user-error "Dape is not available"))
  (save-buffer)
  (let* ((default-directory (mod-python--working-directory))
         (base-config (copy-tree (alist-get 'debugpy dape-configs)))
         (python (mod-python--python-executable)))
    (unless base-config
      (user-error "Dape debugpy config is unavailable"))
    (setq base-config (plist-put base-config 'command python))
    (setq base-config (plist-put base-config :program buffer-file-name))
    (setq base-config (plist-put base-config :args (vconcat args)))
    (setq base-config (plist-put base-config :cwd default-directory))
    (dape base-config)))

(defun mod-python-debug-restart ()
  "Restart the active Python Dape session, or launch the current file."
  (interactive)
  (if (mod-python--dape-session-active-p)
      (dape-restart)
    (mod-python-debug-file
     (mod-python-read-args "Python debug args: " 'mod-python-last-debug-args))))

(when (and (fboundp 'python-ts-mode)
           (fboundp 'treesit-language-available-p)
           (treesit-language-available-p 'python))
  (add-to-list 'major-mode-remap-alist '(python-mode . python-ts-mode)))

(add-hook 'python-base-mode-hook #'mod-python-setup)

(use-package eglot
  :ensure nil
  :commands (eglot-ensure eglot-format-buffer eglot-rename eglot-reconnect)
  :config
  (add-to-list
   'eglot-server-programs
   `((python-mode python-ts-mode)
     . ,(eglot-alternatives mod-python-language-server-candidates))))

(use-package dape
  :ensure t
  :commands (dape dape-breakpoint-toggle)
  :config
  (add-hook 'dape-start-hook #'mod-python--refresh-debugger-key-buffers)
  (add-hook 'dape-update-ui-hook #'mod-python--refresh-debugger-key-buffers))

(with-eval-after-load 'evil
  (evil-define-minor-mode-key
    'normal
    'mod-python-debugger-keys-mode
    (kbd "c") #'dape-continue
    (kbd "n") #'dape-next
    (kbd "i") #'dape-step-in
    (kbd "o") #'dape-step-out
    (kbd "p") #'dape-pause
    (kbd "r") #'mod-python-debug-restart
    (kbd "q") #'dape-kill
    (kbd "b") #'dape-breakpoint-toggle
    (kbd "x") #'dape-breakpoint-remove-at-point
    (kbd "w") #'dape-watch-dwim
    (kbd "R") #'dape-repl
    (kbd "I") #'dape-info)
  (evil-define-minor-mode-key
    'motion
    'mod-python-debugger-keys-mode
    (kbd "c") #'dape-continue
    (kbd "n") #'dape-next
    (kbd "i") #'dape-step-in
    (kbd "o") #'dape-step-out
    (kbd "p") #'dape-pause
    (kbd "r") #'mod-python-debug-restart
    (kbd "q") #'dape-kill
    (kbd "b") #'dape-breakpoint-toggle
    (kbd "x") #'dape-breakpoint-remove-at-point
    (kbd "w") #'dape-watch-dwim
    (kbd "R") #'dape-repl
    (kbd "I") #'dape-info))

(provide 'mod-python)

;;; mod-python.el ends here
