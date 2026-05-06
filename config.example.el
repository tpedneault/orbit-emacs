;;; config.el --- User overrides for orbit-emacs -*- lexical-binding: t; -*-

;; This file is a complete sample user config for orbit-emacs.
;; Every currently supported `orbit-user-*` setting is listed here and set to
;; its current default value.
;;
;; Practical reading guide:
;; - nil usually means “use orbit-emacs defaults / auto-detect”.
;; - t / nil / 'inherit mode overrides follow the per-feature comments below.
;; - copy this to ~/.orbit-emacs.d/config.el and edit only the parts you want.

;; ─── General paths and shell ────────────────────────────────────────────────

;; Shell used for `shell-file-name` and `explicit-shell-file-name`.
;; Leave nil to keep your platform / environment default.
(setq orbit-user-shell nil)

;; Default Org directory used by notes, agenda, capture, and Jira storage.
;; Leave nil to keep orbit-emacs' default under ~/org/.
(setq orbit-user-org-directory nil)

;; Directory containing personal YASnippet snippets.
;; Leave nil to use ~/.orbit-emacs.d/snippets/.
(setq orbit-user-snippets-directory nil)

;; ─── Fonts ──────────────────────────────────────────────────────────────────

;; Monospace UI/editor font settings.
;; Leave these nil to use the built-in orbit-emacs defaults and platform
;; fallback behavior.
(setq orbit-user-font-family nil)
(setq orbit-user-font-height nil)
(setq orbit-user-font-weight nil)

;; Optional variable-pitch face settings for prose-oriented buffers.
;; Leave these nil to keep the current orbit-emacs defaults, or leave
;; `orbit-user-variable-pitch-font` nil to stay effectively monospace.
(setq orbit-user-variable-pitch-font nil)
(setq orbit-user-variable-pitch-height nil)
(setq orbit-user-variable-pitch-weight nil)

;; ─── Editor defaults ────────────────────────────────────────────────────────

;; Global whitespace / current-line / fill-column indicator defaults.
;; These apply broadly unless a mode-specific override says otherwise.
(setq orbit-user-enable-fill-column-indicator t)
(setq orbit-user-fill-column 120)
(setq orbit-user-enable-whitespace t)
(setq orbit-user-enable-hl-line t)

;; ─── Search and external tools ──────────────────────────────────────────────

;; Tool overrides. Leave nil to use `executable-find` and the normal PATH.
(setq orbit-user-rg-program nil)
(setq orbit-user-ctags-program nil)

;; ─── Tcl workflow ───────────────────────────────────────────────────────────

;; Tcl formatter / linter overrides.
(setq orbit-user-tclint-program nil)
(setq orbit-user-tclfmt-program nil)

;; Tcl editing defaults.
(setq orbit-user-tcl-indent-width 3)
(setq orbit-user-tcl-fill-column 120)
(setq orbit-user-tcl-use-tabs nil)

;; Tcl mode-specific UI overrides.
;; Use:
;; - t to force-enable in Tcl buffers
;; - nil to force-disable in Tcl buffers
;; - 'inherit to follow the global orbit-user-* default above
(setq orbit-user-tcl-enable-fill-column-indicator 'inherit)
(setq orbit-user-tcl-enable-whitespace 'inherit)
(setq orbit-user-tcl-enable-hl-line 'inherit)

;; Tcl folding and external symbol helpers.
(setq orbit-user-tcl-auto-fold-definitions nil)
(setq orbit-user-tcl-auto-fold-doxygen-comments nil)
(setq orbit-user-tcl-known-symbols-file nil)

;; Tcl docs / Doxygen integration.
;; Leave these nil to use project-local defaults when available.
(setq orbit-user-tcl-doxygen-xml-directory nil)
(setq orbit-user-doxygen-program nil)
(setq orbit-user-doxygen-config-file nil)

;; ─── Git — forge and magit-delta ────────────────────────────────────────────

;; Hostname of the self-hosted GitLab instance for forge MR / issue browsing.
;; Example: "gitlab.example.com"
;; Also add an authinfo entry:
;;   machine gitlab.example.com login USERNAME^forge password YOUR_GITLAB_PAT
(setq orbit-user-forge-gitlab-host nil)

;; GitLab username (display only; credentials come from ~/.authinfo).
(setq orbit-user-forge-gitlab-username nil)

;; Path to the delta diff-highlight tool.
;; Leave nil to locate delta on PATH (installed via `brew install git-delta').
(setq orbit-user-delta-program nil)

;; ─── org-roam knowledge base ────────────────────────────────────────────────

;; Directory for org-roam nodes.
;; Leave nil to default to roam/ inside orbit-user-org-directory (or ~/org/).
(setq orbit-user-roam-directory nil)

;; ─── Jira integration ───────────────────────────────────────────────────────

;; Read-only and explicit-write Jira workflows use these settings.
;; Keep secrets out of this file where possible; prefer a token command or an
;; environment variable that prints / exposes the PAT at runtime.
(setq orbit-user-jira-base-url nil)
(setq orbit-user-jira-api-prefix "/rest/api/2")
(setq orbit-user-jira-project-key nil)
(setq orbit-user-jira-username nil)
(setq orbit-user-jira-jql nil)
(setq orbit-user-jira-org-file nil)
(setq orbit-user-jira-token-command nil)
(setq orbit-user-jira-pat-env nil)

