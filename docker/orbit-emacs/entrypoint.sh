#!/usr/bin/env bash
set -euo pipefail

ORBIT_UID="${ORBIT_UID:-1000}"
ORBIT_GID="${ORBIT_GID:-1000}"
ORBIT_HOME="${ORBIT_HOME:-/home/orbit}"
ORBIT_CONFIG_SOURCE="${ORBIT_CONFIG_SOURCE:-/opt/orbit-emacs}"
ORBIT_CONFIG_HOME="${ORBIT_HOME}/.config/emacs"
ORBIT_USER_HOME="${ORBIT_HOME}/.orbit-emacs.d"
ORBIT_VAR_HOME="${ORBIT_CONFIG_HOME}/var"
ORBIT_VAR_SEED="/opt/orbit-emacs-var-seed"
ORBIT_GROUP="orbit"

if [[ "${ORBIT_GID}" != "$(id -g orbit)" ]]; then
  if getent group "${ORBIT_GID}" >/dev/null; then
    ORBIT_GROUP="$(getent group "${ORBIT_GID}" | cut -d: -f1)"
  else
    groupmod --gid "${ORBIT_GID}" orbit
  fi
fi

if [[ "${ORBIT_UID}" != "$(id -u orbit)" ]] || [[ "${ORBIT_GROUP}" != "orbit" ]]; then
  usermod --uid "${ORBIT_UID}" --gid "${ORBIT_GROUP}" orbit
fi

mkdir -p "${ORBIT_HOME}/.config" "${ORBIT_USER_HOME}" "${ORBIT_VAR_HOME}" /workspace
rsync -a --delete --exclude var/ "${ORBIT_CONFIG_SOURCE}/" "${ORBIT_CONFIG_HOME}/"

if [[ -d "${ORBIT_VAR_SEED}" ]] && [[ -z "$(find "${ORBIT_VAR_HOME}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  rsync -a "${ORBIT_VAR_SEED}/" "${ORBIT_VAR_HOME}/"
fi

if [[ ! -f "${ORBIT_USER_HOME}/config.el" ]]; then
  cp "${ORBIT_CONFIG_HOME}/config.example.el" "${ORBIT_USER_HOME}/config.el"
fi

chown -R orbit:"${ORBIT_GROUP}" "${ORBIT_HOME}"

exec "$@"
