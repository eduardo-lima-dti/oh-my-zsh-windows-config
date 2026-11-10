#!/usr/bin/env bash
#
# One-time setup: zsh + Oh My Zsh + the Dev Containers theme in Git Bash (Git for Windows).
#
# Mirrors what the Dev Containers "common-utils" feature does on Linux
# (https://github.com/devcontainers/features/tree/main/src/common-utils):
#   1. install zsh                 -> here: MSYS2 zsh package unpacked into the Git for Windows root
#   2. clone Oh My Zsh             -> same flags as the feature (shallow, LF line endings)
#   3. add the devcontainers theme -> downloaded from devcontainers/features
#   4. write ~/.zshrc              -> Oh My Zsh template + ZSH_THEME + updates disabled
#   5. make zsh the default shell  -> here: ~/.bashrc execs zsh in interactive terminals
#
# Everything comes from the internet; nothing is read from the host besides Git for Windows itself.
# Safe to re-run: existing files that would change are backed up to <file>.bak-<timestamp>.
#
# Run from Git Bash:   bash install.sh
#
# Optional environment variables:
#   OMZ_THEME=devcontainers          theme written to ~/.zshrc
#   OMZ_PLUGINS="git"                space-separated plugin list written to ~/.zshrc
#   DEVCONTAINERS_FEATURES_REF=main  git ref of devcontainers/features to take the theme from
#   MSYS2_ZSH_PKG_URL=<url>          pin a specific MSYS2 zsh package instead of the latest
#   SKIP_ZSH_INSTALL=1               do not install/upgrade zsh
#   FORCE_ZSH_INSTALL=1              reinstall zsh even if it is already present
#   SKIP_BASHRC=1                    do not make zsh the default shell in Git Bash

set -euo pipefail

OMZ_THEME="${OMZ_THEME:-devcontainers}"
OMZ_PLUGINS="${OMZ_PLUGINS:-git}"
DEVCONTAINERS_FEATURES_REF="${DEVCONTAINERS_FEATURES_REF:-main}"
MSYS2_REPO="https://repo.msys2.org/msys/x86_64"
THEME_URL="https://raw.githubusercontent.com/devcontainers/features/${DEVCONTAINERS_FEATURES_REF}/src/common-utils/scripts/devcontainers.zsh-theme"
OMZ_REPO="https://github.com/ohmyzsh/ohmyzsh"

OMZ_DIR="${HOME}/.oh-my-zsh"
ZSHRC="${HOME}/.zshrc"
BASHRC="${HOME}/.bashrc"
BASH_PROFILE="${HOME}/.bash_profile"
STAMP="$(date +%Y%m%d-%H%M%S)"
BLOCK_BEGIN="# >>> oh-my-zsh-windows-config >>>"
BLOCK_END="# <<< oh-my-zsh-windows-config <<<"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Write $2 (a temp file) to $1, backing up $1 first if it exists and differs.
install_file() {
    local target="$1" new="$2"
    if [ -f "${target}" ] && cmp -s "${target}" "${new}"; then
        log "${target} already up to date"
        return
    fi
    if [ -f "${target}" ]; then
        cp -f "${target}" "${target}.bak-${STAMP}"
        log "Backed up ${target} -> ${target}.bak-${STAMP}"
    fi
    cp -f "${new}" "${target}"
    log "Wrote ${target}"
}

# ---------------------------------------------------------------------------
# 0. Preconditions
# ---------------------------------------------------------------------------
case "$(uname -s)" in
    MINGW*|MSYS*) ;;
    *) die "This script is meant to run in Git Bash (Git for Windows). Detected: $(uname -s)" ;;
esac
command -v git  >/dev/null || die "git not found"
command -v curl >/dev/null || die "curl not found"
command -v cygpath >/dev/null || die "cygpath not found (is this really Git Bash?)"

# ---------------------------------------------------------------------------
# 1. zsh (MSYS2 package unpacked into the Git for Windows root)
# ---------------------------------------------------------------------------
install_zsh() {
    local pkg_url pkg_file git_root_win sys_tar
    if [ -n "${MSYS2_ZSH_PKG_URL:-}" ]; then
        pkg_url="${MSYS2_ZSH_PKG_URL}"
    else
        local latest
        latest="$(curl -fsSL "${MSYS2_REPO}/" \
            | grep -oE 'zsh-[0-9][^"]*-x86_64\.pkg\.tar\.zst"' | tr -d '"' | sort -V | tail -n 1)"
        [ -n "${latest}" ] || die "Could not find a zsh package in ${MSYS2_REPO}"
        pkg_url="${MSYS2_REPO}/${latest}"
    fi
    pkg_file="${TMP_DIR}/$(basename "${pkg_url}")"
    log "Downloading ${pkg_url}"
    curl -fsSL "${pkg_url}" -o "${pkg_file}"

    # Windows' built-in bsdtar understands .zst; Git for Windows' GNU tar usually lacks zstd.
    sys_tar="$(cygpath "${SYSTEMROOT:-C:\\Windows}")/System32/tar.exe"
    [ -x "${sys_tar}" ] || die "Windows tar.exe not found at ${sys_tar} (needs Windows 10 1803+)"
    "${sys_tar}" -tf "$(cygpath -w "${pkg_file}")" >/dev/null 2>&1 \
        || die "Your Windows tar.exe cannot read .zst archives. Update Windows or install zsh manually."

    git_root_win="$(cygpath -w /)"
    git_root_win="${git_root_win%\\}"
    log "Unpacking zsh into ${git_root_win}"

    if ( : > /usr/bin/.omz-write-test ) 2>/dev/null; then
        rm -f /usr/bin/.omz-write-test
        "${sys_tar}" -xf "$(cygpath -w "${pkg_file}")" -C "${git_root_win}" usr etc
    else
        # Git is installed for all users (e.g. C:\Program Files\Git): elevate only the unpack step.
        log "Git root is not writable; asking for administrator rights (UAC prompt)..."
        local ps_cmd
        ps_cmd="\$p = Start-Process -FilePath '$(cygpath -w "${sys_tar}")' -Verb RunAs -Wait -PassThru -WindowStyle Hidden"
        ps_cmd+=" -ArgumentList '-xf \"$(cygpath -w "${pkg_file}")\" -C \"${git_root_win}\" usr etc';"
        ps_cmd+=" exit \$p.ExitCode"
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "${ps_cmd}" \
            || die "Elevated unpack failed. Re-run Git Bash as Administrator, or set SKIP_ZSH_INSTALL=1."
    fi

    hash -r
    [ -x /usr/bin/zsh ] || die "zsh was not installed to /usr/bin/zsh"
    log "Installed $(/usr/bin/zsh --version)"
}

if [ "${SKIP_ZSH_INSTALL:-0}" = "1" ]; then
    log "Skipping zsh install (SKIP_ZSH_INSTALL=1)"
elif [ -x /usr/bin/zsh ] && [ "${FORCE_ZSH_INSTALL:-0}" != "1" ]; then
    log "zsh already installed: $(/usr/bin/zsh --version) (set FORCE_ZSH_INSTALL=1 to reinstall)"
else
    install_zsh
fi
command -v zsh >/dev/null || die "zsh is not available"

# ---------------------------------------------------------------------------
# 2. Oh My Zsh (same clone flags as the devcontainers feature)
# ---------------------------------------------------------------------------
if [ -d "${OMZ_DIR}" ]; then
    log "Oh My Zsh already present at ${OMZ_DIR}"
else
    log "Cloning Oh My Zsh into ${OMZ_DIR}"
    umask g-w,o-w
    # core.autocrlf=false matters on Windows: CRLF breaks zsh scripts.
    git clone --depth=1 \
        -c core.eol=lf \
        -c core.autocrlf=false \
        -c fsck.zeroPaddedFilemode=ignore \
        -c fetch.fsck.zeroPaddedFilemode=ignore \
        -c receive.fsck.zeroPaddedFilemode=ignore \
        "${OMZ_REPO}" "${OMZ_DIR}"
    git -C "${OMZ_DIR}" repack -a -d -f --depth=1 --window=1 -q
fi

# ---------------------------------------------------------------------------
# 3. Dev Containers theme (+ "codespaces" alias, like the feature)
# ---------------------------------------------------------------------------
THEMES_DIR="${OMZ_DIR}/custom/themes"
mkdir -p "${THEMES_DIR}"
log "Downloading devcontainers theme (${DEVCONTAINERS_FEATURES_REF})"
curl -fsSL "${THEME_URL}" -o "${TMP_DIR}/devcontainers.zsh-theme"
grep -q '__zsh_prompt' "${TMP_DIR}/devcontainers.zsh-theme" || die "Downloaded theme looks wrong: ${THEME_URL}"
install_file "${THEMES_DIR}/devcontainers.zsh-theme" "${TMP_DIR}/devcontainers.zsh-theme"
install_file "${THEMES_DIR}/codespaces.zsh-theme"    "${TMP_DIR}/devcontainers.zsh-theme"

# Git Bash does not set $USER, which the theme's terminal-title hook uses
# (the devcontainers rc_snippet.sh does the same fix).
cat > "${TMP_DIR}/git-bash.zsh" <<'EOF'
# Managed by oh-my-zsh-windows-config (install.sh). Loaded automatically by Oh My Zsh.
if [ -z "${USER:-}" ]; then export USER="$(whoami)"; fi
EOF
install_file "${OMZ_DIR}/custom/git-bash.zsh" "${TMP_DIR}/git-bash.zsh"

# ---------------------------------------------------------------------------
# 4. ~/.zshrc (Oh My Zsh template + theme + updates disabled, like the feature)
# ---------------------------------------------------------------------------
echo "${OMZ_THEME}" | grep -qE '^[a-zA-Z0-9_.-]+$' || die "Invalid OMZ_THEME: ${OMZ_THEME}"
echo "${OMZ_PLUGINS}" | grep -qE '^[a-zA-Z0-9_. -]+$' || die "Invalid OMZ_PLUGINS: ${OMZ_PLUGINS}"
TEMPLATE="${OMZ_DIR}/templates/zshrc.zsh-template"
[ -f "${TEMPLATE}" ] || die "Template not found: ${TEMPLATE}"
{
    sed -e "s/^ZSH_THEME=.*/ZSH_THEME=\"${OMZ_THEME}\"/" \
        -e "s/^plugins=(.*)/plugins=(${OMZ_PLUGINS})/" \
        "${TEMPLATE}" | tr -d '\r'
    printf '\nzstyle '"'"':omz:update'"'"' mode disabled\n'
} > "${TMP_DIR}/zshrc"
install_file "${ZSHRC}" "${TMP_DIR}/zshrc"

# ---------------------------------------------------------------------------
# 5. Start zsh from Git Bash (Git for Windows has no chsh)
# ---------------------------------------------------------------------------
if [ "${SKIP_BASHRC:-0}" = "1" ]; then
    log "Skipping ~/.bashrc (SKIP_BASHRC=1)"
else
    {
        if [ -f "${BASHRC}" ]; then
            # Drop a previous managed block, keep everything else.
            sed "/^${BLOCK_BEGIN}\$/,/^${BLOCK_END}\$/d" "${BASHRC}"
        fi
        cat <<EOF
${BLOCK_BEGIN}
# Switch interactive Git Bash terminals to zsh (Oh My Zsh). Scripts are unaffected.
if [[ \$- == *i* ]] && [ -t 1 ] && [ -z "\${ZSH_VERSION:-}" ] && command -v zsh >/dev/null 2>&1; then
  exec zsh
fi
${BLOCK_END}
EOF
    } > "${TMP_DIR}/bashrc"
    install_file "${BASHRC}" "${TMP_DIR}/bashrc"

    # Git Bash only reads ~/.bashrc through ~/.bash_profile (same content Git for Windows generates).
    if [ ! -e "${BASH_PROFILE}" ] && [ ! -e "${HOME}/.bash_login" ] && [ ! -e "${HOME}/.profile" ]; then
        printf '# generated by Git for Windows\ntest -f ~/.profile && . ~/.profile\ntest -f ~/.bashrc && . ~/.bashrc\n' \
            > "${BASH_PROFILE}"
        log "Wrote ${BASH_PROFILE}"
    fi
fi

log "Done. Open a new Git Bash window (or run: exec zsh)."
