# syntax=docker/dockerfile:1

ARG DEBIAN_VERSION=bookworm
FROM debian:${DEBIAN_VERSION}

ARG TCLINT_VERSION=0.8.0
ARG DEBIAN_FRONTEND=noninteractive

ENV PATH=/opt/tclint/bin:/opt/uv:/usr/local/bin:/usr/bin:/bin
ENV UV_TOOL_DIR=/opt/uv-tools
ENV UV_TOOL_BIN_DIR=/usr/local/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    doxygen \
    fd-find \
    git \
    graphviz \
    openssh-client \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    tcl \
    tcl-dev \
    tk \
    tk-dev \
    universal-ctags \
  && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/tclint \
  && /opt/tclint/bin/pip install --no-cache-dir --upgrade pip \
  && /opt/tclint/bin/pip install --no-cache-dir "tclint==${TCLINT_VERSION}" \
  && ln -sf /opt/tclint/bin/tclint /usr/local/bin/tclint \
  && ln -sf /opt/tclint/bin/tclfmt /usr/local/bin/tclfmt

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/opt/uv sh \
  && chmod -R a+rx /opt/uv \
  && ln -sf /opt/uv/uv /usr/local/bin/uv \
  && ln -sf /opt/uv/uvx /usr/local/bin/uvx \
  && /opt/uv/uv tool install basedpyright \
  && /opt/uv/uv tool install ruff \
  && /opt/uv/uv tool install debugpy \
  && chmod -R a+rX /opt/uv-tools

WORKDIR /workspace

CMD ["bash"]
