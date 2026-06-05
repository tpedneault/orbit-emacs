# orbit-emacs

`orbit-emacs` is a handcrafted Emacs workbench for modal, keyboard-first engineering work. It is built around Evil, project/context switching, a quiet text-first UI, and a small command language under `SPC`.

The primary supported way to run it is the Docker VNC workbench. That gives you the same Linux Emacs, packages, fonts, and external tools on Windows workstations, Linux VMs, and other Docker-capable machines without hunting for a compatible local Emacs build or installing Tcl/Doxygen tooling by hand.

## What You Get

- Emacs 30.2 GUI in a Linux container, exposed through VNC on `localhost`.
- Orbit Emacs config baked into the image and loaded from `/home/orbit/.config/emacs`.
- Prewarmed Elpaca package state so first startup is not a fresh package bootstrap.
- Common engineering tools: Git, ripgrep, Universal Ctags, Doxygen, Graphviz, Tcl/Tk, Python, `tclint`, and `tclfmt`.
- Persistent user config and snippets in `/home/orbit/.orbit-emacs.d`.
- Persistent Emacs runtime/package state in `/home/orbit/.config/emacs/var`.
- Project files mounted at `/workspace`.

Core editor features:

- Evil-first modal editing.
- Perspective-backed contexts/workspaces.
- Minimal, text-first visual design.
- Project, Git, Dired, Org, Python, Tcl, Mermaid, Jira, and SCOS-2000 MIB workflows.
- `SPC` leader and `SPC m` mode-local command language.

## Quick Start: Docker Workbench

Prerequisites:

- Docker with Compose support.
- A VNC client.
- This repository checked out locally.

Build the image:

```sh
scripts/orbit-docker build
```

Start Orbit Emacs with a project mounted at `/workspace`:

```sh
scripts/orbit-docker up /path/to/project
```

Connect your VNC client to:

```text
localhost:5901
```

Useful commands:

```sh
scripts/orbit-docker shell
scripts/orbit-docker logs
scripts/orbit-docker stop
```

Useful runtime overrides:

```sh
ORBIT_VNC_PORT=5902 scripts/orbit-docker up /path/to/project
VNC_GEOMETRY=2560x1440 scripts/orbit-docker up /path/to/project
VNC_PASSWORD='change-me' scripts/orbit-docker up /path/to/project
```

The VNC port is bound to host `127.0.0.1` by `docker-compose.yml`.

## Docker Architecture

The workbench image is defined in:

- `docker/orbit-emacs/Dockerfile`
- `docker/orbit-emacs/entrypoint.sh`
- `docker/orbit-emacs/supervisord.conf`
- `docker-compose.yml`
- `scripts/orbit-docker`

Inside the container:

- `Xvfb` provides the virtual display.
- `openbox` provides a lightweight window manager.
- `x11vnc` exposes the display over VNC.
- GUI Emacs starts in `/workspace`.

Docker volumes:

| Volume | Container Path | Purpose |
| --- | --- | --- |
| `orbit-emacs-var` | `/home/orbit/.config/emacs/var` | Elpaca packages and runtime state |
| `orbit-emacs-user` | `/home/orbit/.orbit-emacs.d` | machine-local `config.el` and snippets |

The image seeds `var/` during build. On first run, an empty `orbit-emacs-var` volume is populated from that seed.

For the full container guide, see [docs/docker.org](docs/docker.org).

## Machine-Local Configuration

Do not edit machine-specific settings directly into the repo config. Use the mounted user-local layer:

```text
/home/orbit/.orbit-emacs.d/config.el
```

Inside Emacs, open it with:

```text
SPC f c u
```

Example SCOS-2000 MIB setup inside the container:

```elisp
(setq orbit-user-mib-roots
      '(("MIB-A" . "/workspace/data/mib-a/")
        ("MIB-B" . "/workspace/data/mib-b/")
        ("MIB-C" . "/workspace/data/mib-c/")
        ("MIB-D" . "/workspace/data/mib-d/")))

(setq orbit-user-mib-icd-version "7.2")
```

Tool overrides are usually unnecessary in the Docker image because the tools are on `PATH`, but you can pin explicit paths when needed:

```elisp
(setq orbit-user-rg-program "rg")
(setq orbit-user-ctags-program "ctags")
(setq orbit-user-doxygen-program "doxygen")
(setq orbit-user-tclint-program "tclint")
(setq orbit-user-tclfmt-program "tclfmt")
```

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

## Local Native Install

The Docker workbench is the recommended path. A local native install is still possible:

1. Put this repository at `~/.config/emacs/`.
2. Install a compatible Emacs locally.
3. Launch Emacs normally.
4. Let Elpaca bootstrap packages into `var/elpaca/`.
5. Put machine-local overrides in `~/.orbit-emacs.d/config.el`.

Native installs are useful on personal machines, but they are not the main deployment target because they require host-level Emacs and toolchain setup.

## Documentation

- [docs/manual.org](docs/manual.org): in-Emacs documentation hub.
- [docs/docker.org](docs/docker.org): Docker/VNC workbench.
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

- `var/`: local package/runtime state, intentionally not part of the image context.
- `.orbit-emacs.d/`: user-local overrides and snippets, mounted as a Docker volume in the workbench.

## Notes For Work Machines

- Use the Docker workbench when host Emacs/tool installation is painful or blocked.
- Keep project files mounted under `/workspace`.
- Keep private credentials out of the image.
- If Git over SSH is needed inside the container, uncomment the read-only `.ssh` and `.gitconfig` mounts in `docker-compose.yml`.
- If company-specific tools replace public `tclint` or `tclfmt`, add them in a derived image or mount them and set the corresponding `orbit-user-*` variables.
