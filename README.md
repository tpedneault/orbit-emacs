# orbit-emacs

`orbit-emacs` is a handcrafted Emacs workbench for modal, keyboard-first engineering work. It is built around Evil, project/context switching, a quiet text-first UI, and a small command language under `SPC`.

The recommended setup is native GUI Emacs on Linux, macOS, or Ubuntu on WSL2 with WSLg. On Windows, WSL2/WSLg gives Orbit a Linux filesystem, Linux tooling, and a real GUI Emacs session.

## What You Get

- Evil-first modal editing.
- Perspective-backed contexts/workspaces.
- Minimal, text-first visual design.
- Project, Git, Dired, Org, Python, Tcl, Mermaid, Jira, and SCOS-2000 MIB workflows.
- `SPC` leader and `SPC m` mode-local command language.
- Machine-local overrides in `~/.orbit-emacs.d/config.el`.

## Install

For the full setup guide, see [docs/install.org](docs/install.org).

### Ubuntu 24.04 On WSL2/WSLg

Install system packages inside Ubuntu:

```sh
sudo apt update
sudo apt install -y \
  emacs-gtk git ripgrep universal-ctags graphviz \
  tcl tcl-dev tk tk-dev python3 python3-venv python3-pip \
  ca-certificates curl
```

Install Doxygen 1.8.17 explicitly. Do not use the Ubuntu `doxygen` package for Tcl docs; newer Doxygen releases dropped the Tcl support this workflow needs.

```sh
cd /tmp
curl -L -o doxygen-1.8.17.linux.bin.tar.gz \
  https://sourceforge.net/projects/doxygen/files/rel-1.8.17/doxygen-1.8.17.linux.bin.tar.gz/download
tar -xzf doxygen-1.8.17.linux.bin.tar.gz
sudo rm -rf /opt/doxygen-1.8.17
sudo mkdir -p /opt
sudo cp -a doxygen-1.8.17 /opt/doxygen-1.8.17
sudo ln -sf /opt/doxygen-1.8.17/bin/doxygen /usr/local/bin/doxygen-1.8.17
doxygen-1.8.17 --version
```

Install Python-based Tcl tools:

```sh
python3 -m venv ~/.local/share/orbit-tools
~/.local/share/orbit-tools/bin/pip install --upgrade pip
~/.local/share/orbit-tools/bin/pip install tclint==0.8.0
```

Make the Tcl tools visible:

```sh
mkdir -p ~/.local/bin
ln -sf ~/.local/share/orbit-tools/bin/tclint ~/.local/bin/tclint
ln -sf ~/.local/share/orbit-tools/bin/tclfmt ~/.local/bin/tclfmt
```

Clone this config inside Ubuntu:

```sh
mkdir -p ~/.config
git clone git@github.com:tpedneault/orbit-emacs.git ~/.config/emacs
```

Start GUI Emacs through WSLg:

```sh
emacs &
```

Keep work repositories inside the Ubuntu filesystem, for example under `~/Repos/`, not under `/mnt/c/...`. This matters for Git, ripgrep, project scans, and general editor responsiveness.

### Machine-Local Configuration

Put local settings in:

```text
~/.orbit-emacs.d/config.el
```

Inside Emacs, open it with:

```text
SPC f c u
```

Example SCOS-2000 MIB setup:

```elisp
(setq orbit-user-mib-roots
      '(("MIB-A" . "~/Repos/my-project/data/mib-a/")
        ("MIB-B" . "~/Repos/my-project/data/mib-b/")
        ("MIB-C" . "~/Repos/my-project/data/mib-c/")
        ("MIB-D" . "~/Repos/my-project/data/mib-d/")))

(setq orbit-user-mib-icd-version "7.2")
```

Tool overrides are optional when tools are on `PATH`, but can be pinned when needed:

```elisp
(setq orbit-user-rg-program "rg")
(setq orbit-user-ctags-program "ctags")
(setq orbit-user-doxygen-program "doxygen-1.8.17")
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

## Documentation

- [docs/install.org](docs/install.org): native and WSL2/WSLg installation.
- [docs/manual.org](docs/manual.org): in-Emacs documentation hub.
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
config.example.el
```

Important generated/runtime paths:

- `var/`: local package/runtime state.
- `~/.orbit-emacs.d/`: user-local overrides and snippets.

## Notes For Work Machines

- Prefer WSL2/WSLg on Windows when available.
- Keep repositories inside the Linux filesystem on WSL2.
- Keep private credentials out of the repo.
- Put machine-specific paths and tool overrides in `~/.orbit-emacs.d/config.el`.
- If company-specific tools replace public `tclint` or `tclfmt`, install them on the WSL/Linux side and set the corresponding `orbit-user-*` variables.
