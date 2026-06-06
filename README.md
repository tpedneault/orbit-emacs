# orbit-emacs

`orbit-emacs` is a handcrafted Emacs workbench for modal, keyboard-first engineering work. It is built around Evil, project/context switching, a quiet text-first UI, and a small command language under `SPC`.

The recommended work setup is:

1. Run GUI Emacs natively on your machine.
2. Keep Tcl, Doxygen, Ctags, ripgrep, and related tooling inside Docker.
3. Let Orbit call small host wrapper scripts as if the tools were installed locally.

This keeps the editor pleasant and native while hiding the painful dependency setup inside a reproducible Linux toolbox image.

## Why This Setup

Native GUI Emacs gives you:

- normal key repeat for Vim movement
- correct clipboard behavior
- native fonts and window resizing
- no VNC/display-server weirdness
- better desktop performance on Windows and macOS

Dockerized tools give you:

- consistent Linux versions of `tclint`, `tclfmt`, `doxygen`, `ctags`, `rg`, `uv`, and Python tooling
- no host-level dependency hunt on work machines
- one image to rebuild when tooling changes
- project files edited directly on the host, not trapped inside a container

## Quick Start: Native Emacs, Docker Tools

Prerequisites:

- Native Emacs installed on the host.
- Docker available.
- This repository checked out as your Emacs config.

Build the toolbox image:

```sh
cd ~/.config/emacs
scripts/orbit-tool build
```

Install wrapper scripts:

```sh
scripts/orbit-tool install-wrappers
```

This creates wrappers in:

```text
~/.orbit-emacs.d/bin/
```

Point Orbit at those wrappers in `~/.orbit-emacs.d/config.el`:

```elisp
(let ((orbit-tool-bin (expand-file-name "~/.orbit-emacs.d/bin/")))
  (add-to-list 'exec-path orbit-tool-bin)
  (setenv "PATH" (concat orbit-tool-bin path-separator (or (getenv "PATH") "")))

  (setq orbit-user-tclint-program (expand-file-name "tclint" orbit-tool-bin))
  (setq orbit-user-tclfmt-program (expand-file-name "tclfmt" orbit-tool-bin))
  (setq orbit-user-doxygen-program (expand-file-name "doxygen" orbit-tool-bin))
  (setq orbit-user-ctags-program (expand-file-name "ctags" orbit-tool-bin))
  (setq orbit-user-rg-program (expand-file-name "rg" orbit-tool-bin)))
```

Then open Emacs natively and validate Tcl tooling from a Tcl buffer:

```text
SPC m v
```

## How The Toolbox Works

The main wrapper is:

```text
scripts/orbit-tool
```

Examples:

```sh
scripts/orbit-tool tclfmt src/example.tcl
scripts/orbit-tool tclint src/example.tcl
scripts/orbit-tool doxygen Doxyfile
scripts/orbit-tool ctags -e -R .
scripts/orbit-tool rg "pattern" .
```

When called from a project, the wrapper:

1. Finds the current Git root, or falls back to the current directory.
2. Mounts that directory into the container at `/workspace`.
3. Translates host absolute paths under that root into `/workspace/...`.
4. Runs the requested tool in the `orbit-emacs-tools:latest` image.

You can force the mounted root:

```sh
ORBIT_TOOL_ROOT=/path/to/project scripts/orbit-tool tclfmt path/to/file.tcl
```

The toolbox image is defined in:

```text
docker/orbit-tools/Dockerfile
```

For details, see [docs/toolbox.org](docs/toolbox.org).

## SCOS-2000 MIB Setup

For MIB work, configure only the MIB directories you actually use:

```elisp
(setq orbit-user-mib-roots
      '(("MIB-A" . "/path/to/project/data/mib-a/")
        ("MIB-B" . "/path/to/project/data/mib-b/")
        ("MIB-C" . "/path/to/project/data/mib-c/")
        ("MIB-D" . "/path/to/project/data/mib-d/")))

(setq orbit-user-mib-icd-version "7.2")
```

Open a configured `.dat` file and use:

- `SPC m c`: jump to column
- `SPC m r`: toggle column ruler
- `SPC m C`: compare the same table across MIB roots
- `SPC m t`: open a table from the current MIB root

## First Keys

The default profile is Vim/Evil-first.

| Key | Action |
| --- | --- |
| `SPC SPC` | switch buffer |
| `SPC .` | find project file |
| `SPC ,` | find any file |
| `SPC /` | search project |
| `SPC x e` | enter project editing context |
| `SPC x f` | enter file-management context |
| `SPC x g` | enter Git context |
| `SPC n a` | open agenda |
| `SPC n t` | capture inbox task |
| `SPC h d` | open manual |

Mode-local commands live under `SPC m`. For example:

- Tcl: `SPC m l` lint, `SPC m f` format, `SPC m v` validate tooling.
- Python: `SPC m e s` start Eglot, `SPC m f b` format, `SPC m d d` debug.
- MIB: `SPC m c` jump column, `SPC m C` compare same table across MIB roots.
- Org: `SPC m r` refile, `SPC m t` TODO state, `SPC m T a` align table.

For the full keymap, see [docs/keybindings.org](docs/keybindings.org).

## Optional: GUI Emacs In Docker

There is an experimental VNC workbench under:

```text
docker/orbit-emacs/
docker-compose.yml
scripts/orbit-docker
```

It builds a full containerized GUI Emacs desktop. This is no longer the recommended path because VNC/display-server behavior can be fiddly compared with native Emacs.

Use it only when native Emacs is not available and you are comfortable debugging container GUI issues. See [docs/docker.org](docs/docker.org).

## Local Native Install

For the recommended setup:

1. Put this repository at `~/.config/emacs/`.
2. Install native Emacs.
3. Launch Emacs normally.
4. Let Elpaca bootstrap packages into `var/elpaca/`.
5. Put machine-local overrides in `~/.orbit-emacs.d/config.el`.
6. Use `scripts/orbit-tool` wrappers for external tools.

## Documentation

- [docs/manual.org](docs/manual.org): in-Emacs documentation hub.
- [docs/toolbox.org](docs/toolbox.org): native Emacs with Dockerized tools.
- [docs/docker.org](docs/docker.org): experimental Docker/VNC workbench.
- [docs/workflow.org](docs/workflow.org): daily working loops.
- [docs/keybindings.org](docs/keybindings.org): full leader and local-leader map.
- [docs/contexts.org](docs/contexts.org): Perspective-backed context model.
- [docs/tcl.org](docs/tcl.org): Tcl workflow.
- [docs/python.org](docs/python.org): Python workflow.
- [docs/org.org](docs/org.org): Org workflow.
- [docs/jira.org](docs/jira.org): Jira sync.
- [docs/vim.org](docs/vim.org): Vim quick reference.
- [docs/troubleshooting.org](docs/troubleshooting.org): common issues.

## Repository Layout

```text
early-init.el
init.el
modules/
packages/
snippets/
docs/
docker/
scripts/
config.example.el
```

Important generated/runtime paths:

- `var/`: local package/runtime state.
- `.orbit-emacs.d/`: user-local overrides and snippets.

## Notes For Work Machines

- Prefer native Emacs plus Dockerized tooling wrappers.
- Keep project files on the host filesystem where Emacs edits them normally.
- Keep private credentials out of Docker images.
- If company-specific tools replace public `tclint` or `tclfmt`, add them to a derived `orbit-emacs-tools` image.
- On Windows native Emacs, use the current wrapper through Git Bash or WSL until dedicated PowerShell wrappers are added.
