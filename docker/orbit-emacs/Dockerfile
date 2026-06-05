# syntax=docker/dockerfile:1

ARG DEBIAN_VERSION=bookworm
FROM debian:${DEBIAN_VERSION}

ARG EMACS_VERSION=30.2
ARG TCLINT_VERSION=0.8.0
ARG DEBIAN_FRONTEND=noninteractive

ENV ORBIT_CONFIG_SOURCE=/opt/orbit-emacs \
    ORBIT_HOME=/home/orbit \
    ORBIT_WORKSPACE=/workspace \
    DISPLAY=:1 \
    VNC_GEOMETRY=1920x1080 \
    VNC_DEPTH=24

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    curl \
    dbus-x11 \
    doxygen \
    fd-find \
    fontconfig \
    fonts-dejavu \
    fonts-dejavu-core \
    fonts-dejavu-extra \
    fonts-firacode \
    fonts-jetbrains-mono \
    gawk \
    git \
    graphviz \
    gzip \
    libacl1-dev \
    libdbus-1-dev \
    libgccjit-12-dev \
    libgif-dev \
    libgnutls28-dev \
    libgtk-3-dev \
    libjansson-dev \
    libjpeg-dev \
    liblcms2-dev \
    libmagickwand-dev \
    libm17n-dev \
    libncurses-dev \
    libotf-dev \
    libpng-dev \
    librsvg2-dev \
    libsqlite3-dev \
    libsystemd-dev \
    libtiff-dev \
    libtool \
    libtree-sitter-dev \
    libwebp-dev \
    libx11-dev \
    libxaw7-dev \
    libxml2-dev \
    libxpm-dev \
    make \
    openbox \
    openssh-client \
    pipx \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    rsync \
    sudo \
    supervisor \
    tcl \
    tcl-dev \
    tk \
    tk-dev \
    universal-ctags \
    wget \
    x11vnc \
    xauth \
    xclip \
    xterm \
    xvfb \
    xz-utils \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://ftp.gnu.org/gnu/emacs/emacs-${EMACS_VERSION}.tar.xz" -o /tmp/emacs.tar.xz \
  && mkdir -p /tmp/emacs-src \
  && tar -xJf /tmp/emacs.tar.xz -C /tmp/emacs-src --strip-components=1 \
  && cd /tmp/emacs-src \
  && ./configure \
       --prefix=/usr/local \
       --with-x-toolkit=gtk3 \
       --with-json \
       --with-tree-sitter \
       --with-native-compilation=aot \
  && make -j"$(nproc)" \
  && make install \
  && cd / \
  && rm -rf /tmp/emacs-src /tmp/emacs.tar.xz

RUN python3 -m venv /opt/tclint \
  && /opt/tclint/bin/pip install --no-cache-dir --upgrade pip \
  && /opt/tclint/bin/pip install --no-cache-dir "tclint==${TCLINT_VERSION}" \
  && ln -sf /opt/tclint/bin/tclint /usr/local/bin/tclint \
  && ln -sf /opt/tclint/bin/tclfmt /usr/local/bin/tclfmt

RUN groupadd --gid 1000 orbit \
  && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash orbit \
  && usermod -aG sudo orbit \
  && printf 'orbit ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/orbit \
  && chmod 0440 /etc/sudoers.d/orbit \
  && mkdir -p /workspace /opt/orbit-emacs /opt/orbit-emacs-var-seed \
  && chown -R orbit:orbit /workspace /opt/orbit-emacs /opt/orbit-emacs-var-seed /home/orbit

COPY --chown=orbit:orbit . /opt/orbit-emacs/
COPY docker/orbit-emacs/entrypoint.sh /usr/local/bin/orbit-entrypoint
COPY docker/orbit-emacs/bin/ /usr/local/bin/
COPY docker/orbit-emacs/supervisord.conf /etc/supervisor/conf.d/orbit-emacs.conf

RUN chmod 0755 /usr/local/bin/orbit-entrypoint /usr/local/bin/orbit-start-emacs /usr/local/bin/orbit-start-vnc \
  && mkdir -p /home/orbit/.config \
  && rsync -a --delete --exclude var/ /opt/orbit-emacs/ /home/orbit/.config/emacs/ \
  && chown -R orbit:orbit /home/orbit/.config \
  && su orbit -c 'HOME=/home/orbit emacs --batch --debug-init -l /home/orbit/.config/emacs/init.el --eval "(when (fboundp (quote elpaca-wait)) (elpaca-wait))" --eval "(message \"orbit-emacs package seed complete\")"' \
  && rsync -a /home/orbit/.config/emacs/var/ /opt/orbit-emacs-var-seed/ \
  && chown -R orbit:orbit /opt/orbit-emacs-var-seed /home/orbit

EXPOSE 5901
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/orbit-entrypoint"]
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/orbit-emacs.conf"]
