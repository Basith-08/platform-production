#!/usr/bin/env bash
# Provision and harden a fresh Ubuntu 24.04 LTS platform host.
#
# SSH hardening is deliberately a separate, explicit phase:
#   bootstrap.sh provision --hostname ... --admin-key ... --deploy-key ...
#   # operator verifies both new SSH sessions
#   bootstrap.sh harden
#
# The old positional one-key interface is rejected instead of silently
# conflating a human credential with the CI credential.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_USER="deploy"
ADMIN_USER="admin"
PROVISION_MARKER="/var/lib/platform/provisioned"
SSH_HARDENING_FILE="/etc/ssh/sshd_config.d/99-platform-hardening.conf"
ADMIN_SUDOERS_FILE="/etc/sudoers.d/90-platform-admin"
STEP_NUMBER=0
CURRENT_STEP="initialization"

usage() {
  cat <<'USAGE'
Usage:
  bootstrap.sh provision --admin-key PATH --deploy-key PATH [--hostname NAME]
  bootstrap.sh harden

Provision prepares the host and leaves SSH password/root access unchanged.
Harden validates the SSH configuration, reloads ssh.service, and verifies the
effective settings. Run harden only after testing admin and deploy SSH access
from new terminals.
USAGE
}

failure_report() {
  local exit_code="$1" line="$2" command="$3"
  printf '\nFAIL: %s\n' "${CURRENT_STEP}" >&2
  printf 'line: %s\ncommand: %s\nexit_code: %s\n' "${line}" "${command}" "${exit_code}" >&2
  if [ ! -f "${PROVISION_MARKER}" ]; then
    echo "Host has NOT been SSH-hardened; root/console recovery access remains available." >&2
  fi
  exit "${exit_code}"
}
trap 'failure_report "$?" "$LINENO" "$BASH_COMMAND"' ERR

step() {
  CURRENT_STEP="$1"
  shift
  STEP_NUMBER=$((STEP_NUMBER + 1))
  printf '[%d] %s ...\n' "${STEP_NUMBER}" "${CURRENT_STEP}"
  "$@"
  printf '    PASS\n'
}

require_root() {
  [ "$(id -u)" -eq 0 ] || {
    echo "Run this command as root." >&2
    return 1
  }
}

validate_host() {
  require_root
  [ -r /etc/os-release ] || {
    echo "/etc/os-release is missing." >&2
    return 1
  }

  # shellcheck disable=SC1091
  . /etc/os-release

  if [ "${ID:-}" != ubuntu ] || [ "${VERSION_ID:-}" != 24.04 ]; then
    echo "Unsupported OS: ${PRETTY_NAME:-unknown}. Required: Ubuntu 24.04 LTS." >&2
    return 1
  fi

  [ "$(dpkg --print-architecture)" = amd64 ] || {
    echo "Unsupported architecture: $(dpkg --print-architecture). Required: amd64." >&2
    return 1
  }

  command -v apt-get >/dev/null 2>&1
  command -v getent >/dev/null 2>&1

  getent hosts github.com >/dev/null || {
    echo "DNS lookup for github.com failed." >&2
    return 1
  }

  getent hosts download.docker.com >/dev/null || {
    echo "DNS lookup for download.docker.com failed." >&2
    return 1
  }
}

validate_public_key() {
  local label="$1" key_file="$2"

  [ -s "${key_file}" ] || {
    echo "${label} public key is missing or empty: ${key_file}" >&2
    return 1
  }

  ssh-keygen -lf "${key_file}" >/dev/null 2>&1 || {
    echo "${label} public key is not structurally valid: ${key_file}" >&2
    return 1
  }
}

validate_hostname() {
  local name="$1"

  [[ "${name}" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || {
    echo "Invalid node hostname '${name}'; use lowercase DNS-label syntax such as prod-sby-01." >&2
    return 1
  }
}

configure_hostname_resolution() {
  local hostname_name="$1"

  [ -n "${hostname_name}" ] || return 0

  validate_hostname "${hostname_name}"

  hostnamectl set-hostname "${hostname_name}"

  if grep -Eq '^[[:space:]]*127\.0\.1\.1[[:space:]]' /etc/hosts; then
    sed -i -E \
      "s/^[[:space:]]*127\.0\.1\.1[[:space:]].*$/127.0.1.1 ${hostname_name}/" \
      /etc/hosts
  else
    printf '127.0.1.1 %s\n' "${hostname_name}" >> /etc/hosts
  fi

  getent hosts "${hostname_name}" >/dev/null || {
    echo "Hostname '${hostname_name}' does not resolve through /etc/hosts." >&2
    return 1
  }
}

ensure_user() {
  local user="$1"

  if id -u "${user}" >/dev/null 2>&1; then
    echo "User ${user} already exists; preserving its home and data."
  else
    adduser --disabled-password --gecos "" "${user}"
  fi
}

install_key() {
  local user="$1" key_file="$2" ssh_dir auth_file

  ssh_dir="/home/${user}/.ssh"
  auth_file="${ssh_dir}/authorized_keys"

  install -d -o "${user}" -g "${user}" -m 0700 "${ssh_dir}"

  touch "${auth_file}"

  if ! grep -Fqx -f "${key_file}" "${auth_file}"; then
    cat "${key_file}" >> "${auth_file}"
  fi

  chmod 600 "${auth_file}"
  chown "${user}:${user}" "${auth_file}"
}

configure_admin_sudo() {
  install -d -m 0755 /etc/sudoers.d

  cat > "${ADMIN_SUDOERS_FILE}" <<EOF
${ADMIN_USER} ALL=(ALL:ALL) NOPASSWD:ALL
EOF

  chmod 0440 "${ADMIN_SUDOERS_FILE}"

  /usr/sbin/visudo -cf "${ADMIN_SUDOERS_FILE}" >/dev/null

  runuser -u "${ADMIN_USER}" -- sudo -n id >/dev/null 2>&1 || {
    echo "Passwordless sudo validation failed for ${ADMIN_USER}." >&2
    return 1
  }
}

configure_identity() {
  local hostname_name="$1" admin_key="$2" deploy_key="$3"

  if [ -n "${hostname_name}" ]; then
    configure_hostname_resolution "${hostname_name}"
  fi

  ensure_user "${ADMIN_USER}"
  ensure_user "${DEPLOY_USER}"

  if id -nG "${DEPLOY_USER}" | tr ' ' '\n' | grep -qx sudo; then
    echo "Existing deploy user is in sudo; use the documented migration procedure before rerunning provision." >&2
    return 1
  fi

  usermod -aG sudo "${ADMIN_USER}"
  usermod -aG docker "${DEPLOY_USER}" 2>/dev/null || true

  install_key "${ADMIN_USER}" "${admin_key}"
  install_key "${DEPLOY_USER}" "${deploy_key}"

  configure_admin_sudo
}

install_base_packages() {
  export DEBIAN_FRONTEND=noninteractive

  apt-get update -y

  apt-get install -y \
    ca-certificates \
    curl \
    cron \
    git \
    gnupg \
    rsync \
    ufw \
    unattended-upgrades \
    util-linux \
    unzip \
    openssh-server

  systemctl enable --now cron
}

install_docker() {
  install -m 0755 -d /etc/apt/keyrings

  curl \
    --fail \
    --location \
    --silent \
    --show-error \
    --connect-timeout 15 \
    --max-time 120 \
    --retry 4 \
    --retry-delay 5 \
    --retry-all-errors \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

  chmod a+r /etc/apt/keyrings/docker.asc

  # shellcheck disable=SC1091
  . /etc/os-release

  printf \
    'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' \
    "${VERSION_CODENAME}" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y

  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin

  systemctl enable --now docker

  usermod -aG docker "${DEPLOY_USER}"
}

configure_firewall_and_updates() {
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable

  dpkg-reconfigure -f noninteractive unattended-upgrades
}

configure_runtime_layout() {
  mkdir -p /srv/platform/{traefik,monitoring,backup,networks,maintenance,automation}
  mkdir -p /srv/platform/backup/staging
  mkdir -p /srv/platform/.staging
  mkdir -p /srv/apps

  install \
    -d \
    -o "${DEPLOY_USER}" \
    -g "${DEPLOY_USER}" \
    -m 0755 \
    /run/lock/platform-backup

  install \
    -d \
    -o "${DEPLOY_USER}" \
    -g "${DEPLOY_USER}" \
    -m 0750 \
    /var/log/platform

  touch \
    /var/log/platform/backup.log \
    /var/log/platform/maintenance.log

  chown "${DEPLOY_USER}:${DEPLOY_USER}" /var/log/platform/*.log
  chown -R "${DEPLOY_USER}:${DEPLOY_USER}" /srv/platform /srv/apps

  install -d -m 0755 /etc/systemd/journald.conf.d

  cat > /etc/systemd/journald.conf.d/size-limit.conf <<'EOF'
[Journal]
SystemMaxUse=300M
EOF

  systemctl restart systemd-journald
  journalctl --vacuum-size=300M

  cat > /etc/logrotate.d/platform <<'EOF'
/var/log/platform/*.log {
    daily
    rotate 14
    size 10M
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    su deploy deploy
}
EOF
}

postflight() {
  id -u "${ADMIN_USER}" >/dev/null
  id -u "${DEPLOY_USER}" >/dev/null

  test -s "/home/${ADMIN_USER}/.ssh/authorized_keys"
  test -s "/home/${DEPLOY_USER}/.ssh/authorized_keys"

  test -s "${ADMIN_SUDOERS_FILE}"
  /usr/sbin/visudo -cf "${ADMIN_SUDOERS_FILE}" >/dev/null

  runuser -u "${ADMIN_USER}" -- sudo -n id >/dev/null 2>&1 || {
    echo "Admin passwordless sudo is not functioning." >&2
    return 1
  }

  if id -nG "${DEPLOY_USER}" | tr ' ' '\n' | grep -qx sudo; then
    echo "Deploy user must not belong to sudo." >&2
    return 1
  fi

  docker info >/dev/null
  docker compose version >/dev/null
  rclone version >/dev/null

  systemctl is-active --quiet cron
  systemctl is-active --quiet docker

  test -d /srv/platform
  test -d /srv/apps

  /usr/sbin/sshd -t

  install -d -m 0755 "$(dirname -- "${PROVISION_MARKER}")"
  touch "${PROVISION_MARKER}"
  chmod 600 "${PROVISION_MARKER}"
}

provision() {
  local admin_key='' deploy_key='' hostname_name='' option

  while [ "$#" -gt 0 ]; do
    option="$1"

    case "${option}" in
      --admin-key)
        [ "$#" -ge 2 ] || {
          echo "--admin-key needs a path." >&2
          return 2
        }
        admin_key="$2"
        shift 2
        ;;

      --deploy-key)
        [ "$#" -ge 2 ] || {
          echo "--deploy-key needs a path." >&2
          return 2
        }
        deploy_key="$2"
        shift 2
        ;;

      --hostname)
        [ "$#" -ge 2 ] || {
          echo "--hostname needs a value." >&2
          return 2
        }
        hostname_name="$2"
        shift 2
        ;;

      -h|--help)
        usage
        return 0
        ;;

      *)
        echo "Unknown provision option: ${option}" >&2
        usage >&2
        return 2
        ;;
    esac
  done

  [ -n "${admin_key}" ] && [ -n "${deploy_key}" ] || {
    echo "provision requires separate --admin-key and --deploy-key paths." >&2
    return 2
  }

  validate_public_key admin "${admin_key}"
  validate_public_key deploy "${deploy_key}"

  [ -z "${hostname_name}" ] || validate_hostname "${hostname_name}"

  step "Validate Ubuntu 24.04 host" \
    validate_host

  step "Configure admin and deploy identities" \
    configure_identity \
    "${hostname_name}" \
    "${admin_key}" \
    "${deploy_key}"

  step "Install base packages" \
    install_base_packages

  step "Install pinned rclone" \
    "${SCRIPT_DIR}/install-rclone.sh"

  step "Install Docker Engine and Compose" \
    install_docker

  step "Configure firewall and security updates" \
    configure_firewall_and_updates

  step "Create runtime layout and logging limits" \
    configure_runtime_layout

  step "Run provisioning postflight" \
    postflight

  printf '\nProvision complete. SSH hardening is intentionally pending.\n'
  echo "Test admin and deploy SSH from new terminals, then run: bootstrap.sh harden"
}

harden() {
  require_root

  [ -f "${PROVISION_MARKER}" ] || {
    echo "Provision phase is not marked complete; refusing to harden SSH." >&2
    return 1
  }

  test -s "/home/${ADMIN_USER}/.ssh/authorized_keys"
  test -s "/home/${DEPLOY_USER}/.ssh/authorized_keys"

  test -s "${ADMIN_SUDOERS_FILE}"
  /usr/sbin/visudo -cf "${ADMIN_SUDOERS_FILE}" >/dev/null

  local backup_file had_previous=0 temporary_file

  backup_file="$(mktemp -t platform-sshd-backup.XXXXXX)"
  temporary_file="$(mktemp -t platform-sshd-config.XXXXXX)"

  trap 'rm -f -- "${backup_file}" "${temporary_file}"' RETURN

  if [ -f "${SSH_HARDENING_FILE}" ]; then
    cp -p "${SSH_HARDENING_FILE}" "${backup_file}"
    had_previous=1
  fi

  cat > "${temporary_file}" <<'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF

  install -d -m 0755 /etc/ssh/sshd_config.d
  install -m 0644 "${temporary_file}" "${SSH_HARDENING_FILE}"

  if ! /usr/sbin/sshd -t; then
    if [ "${had_previous}" -eq 1 ]; then
      cp -p "${backup_file}" "${SSH_HARDENING_FILE}"
    else
      rm -f "${SSH_HARDENING_FILE}"
    fi

    echo "Invalid SSH configuration; previous configuration restored." >&2
    return 1
  fi

  systemctl reload ssh.service

  local effective
  effective="$(/usr/sbin/sshd -T)"

  grep -qx 'passwordauthentication no' <<< "${effective}"
  grep -qx 'permitrootlogin no' <<< "${effective}"
  grep -qx 'pubkeyauthentication yes' <<< "${effective}"

  echo "SSH hardening complete: ssh.service reloaded and effective settings verified."
}

command_name="${1:-}"
shift || true

case "${command_name}" in
  provision)
    provision "$@"
    ;;

  harden)
    [ "$#" -eq 0 ] || {
      echo "harden accepts no options." >&2
      usage >&2
      exit 2
    }
    harden
    ;;

  -h|--help)
    usage
    ;;

  *)
    echo "A subcommand is required. The old positional one-key interface is no longer accepted." >&2
    usage >&2
    exit 2
    ;;
esac