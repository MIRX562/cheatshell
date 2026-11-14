#!/usr/bin/env bash
#
# cheatshell installer
#
# Installs the launcher into your Quickshell configuration directory, checks
# that the runtime can run it, and writes a starter config on first install.
# Safe to re-run.
#
# One-liner (no clone required):
#   curl -fsSL https://raw.githubusercontent.com/MIRX562/cheatshell/main/install.sh | bash
#
# Or run it from a local source directory — local files are used automatically.
#
# Usage:
#   ./install.sh                    interactive install
#   ./install.sh --yes              non-interactive install
#   ./install.sh --notes-dir DIR    notes folder for the starter config
#   ./install.sh --target DIR       install somewhere other than
#                                   ${XDG_CONFIG_HOME:-~/.config}/quickshell/cheatshell
#   ./install.sh --source DIR       install from a local copy instead of GitHub
#   ./install.sh --ref BRANCH       download a branch/tag (default: main)
#   ./install.sh --no-config        do not create a starter config
#   ./install.sh --uninstall        remove the installed app (keeps config)
#   ./install.sh --uninstall --purge
#                                   also remove ${XDG_CONFIG_HOME:-~/.config}/cheatshell
#
set -euo pipefail

APP_NAME="cheatshell"
REPO_SLUG="${CHEATSHELL_REPO_SLUG:-MIRX562/cheatshell}"
REF="${CHEATSHELL_REF:-main}"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET_DIR="$CONFIG_HOME/quickshell/$APP_NAME"
CONFIG_DIR="$CONFIG_HOME/$APP_NAME"
CONFIG_FILE="$CONFIG_DIR/config.json"

ASSUME_YES=0
WRITE_CONFIG=1
UNINSTALL=0
PURGE=0
NOTES_DIR="${CHEATSHELL_NOTES_DIR:-$HOME/Notes/commands}"
SOURCE_OVERRIDE=""

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m    %s\n' "$*"; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$*"; }
fail() { printf '  \033[31mfail\033[0m  %s\n' "$*"; }
die()  { fail "$*"; exit 1; }

usage() {
    cat <<'USAGE'
cheatshell installer

Installs the launcher into your Quickshell configuration directory, checks
that the runtime can run it, and writes a starter config on install.
Safe to re-run.

One-liner (no clone required):
  curl -fsSL https://raw.githubusercontent.com/MIRX562/cheatshell/main/install.sh | bash

Usage:
  ./install.sh                    interactive install
  ./install.sh --yes              non-interactive install
  ./install.sh --notes-dir DIR    notes folder for the starter config
  ./install.sh --target DIR       custom app install location
  ./install.sh --source DIR       install from a local copy instead of GitHub
  ./install.sh --ref BRANCH       download a branch/tag (default: main)
  ./install.sh --no-config        do not create a starter config
  ./install.sh --uninstall        remove the installed app (keeps config)
  ./install.sh --uninstall --purge
                                  also remove the config directory
  ./install.sh --help             show this help
USAGE
    exit 0
}

# Reads a line from the terminal even when the script itself arrived on stdin
# (curl | bash). Returns non-zero when no terminal is available.
ask() {
    local __var="$1" __prompt="$2" __answer=""
    printf '%s' "$__prompt"
    if [ -t 0 ]; then
        IFS= read -r __answer || true
    elif [ -r /dev/tty ]; then
        IFS= read -r __answer < /dev/tty || true
    else
        printf '\n'
        return 1
    fi
    printf -v "$__var" '%s' "$__answer"
}

expand_path() {
    case "$1" in
        "~")    printf '%s' "$HOME" ;;
        "~/"*)  printf '%s/%s' "$HOME" "${1#\~/}" ;;
        /*)     printf '%s' "$1" ;;
        *)      printf '%s/%s' "$PWD" "$1" ;;
    esac
}

config_path() {
    case "$1" in
        "$HOME")   printf '~' ;;
        "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
        *)         printf '%s' "$1" ;;
    esac
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# version_ge A B -> true when A >= B
version_ge() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES=1 ;;
        --target)
            [ $# -ge 2 ] || die "--target needs a directory"
            TARGET_DIR="$2"
            shift
            ;;
        --source)
            [ $# -ge 2 ] || die "--source needs a directory"
            SOURCE_OVERRIDE="$2"
            shift
            ;;
        --notes-dir)
            [ $# -ge 2 ] || die "--notes-dir needs a directory"
            NOTES_DIR="$2"
            shift
            ;;
        --ref)
            [ $# -ge 2 ] || die "--ref needs a branch or tag"
            REF="$2"
            shift
            ;;
        --no-config) WRITE_CONFIG=0 ;;
        --uninstall) UNINSTALL=1 ;;
        --purge) PURGE=1 ;;
        -h|--help) usage ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

if [ "$PURGE" -eq 1 ] && [ "$UNINSTALL" -ne 1 ]; then
    die "--purge can only be used with --uninstall"
fi

# ---------------------------------------------------------------------------
# Source resolution: local checkout or GitHub tarball
# ---------------------------------------------------------------------------

SRC_DIR=""
FETCH_DIR=""

resolve_local_source() {
    if [ -n "$SOURCE_OVERRIDE" ]; then
        [ -f "$SOURCE_OVERRIDE/shell.qml" ] || die "--source does not look like cheatshell: $SOURCE_OVERRIDE"
        SRC_DIR="$(cd -- "$SOURCE_OVERRIDE" && pwd)"
        return 0
    fi

    local script="${BASH_SOURCE[0]:-}"
    if [ -n "$script" ] && [ -f "$script" ]; then
        local dir
        dir="$(cd -- "$(dirname -- "$script")" && pwd)"
        if [ -f "$dir/shell.qml" ]; then
            SRC_DIR="$dir"
        fi
    fi
}

fetch_source() {
    [ -z "$SRC_DIR" ] || return 0

    local downloader=""
    if command -v curl >/dev/null 2>&1; then
        downloader="curl"
    elif command -v wget >/dev/null 2>&1; then
        downloader="wget"
    else
        die "curl or wget is required to download cheatshell"
    fi

    FETCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cheatshell-install.XXXXXX")"
    trap 'rm -rf -- "$FETCH_DIR"' EXIT

    local url="${CHEATSHELL_TARBALL_URL:-https://codeload.github.com/$REPO_SLUG/tar.gz/refs/heads/$REF}"
    say "Downloading $REPO_SLUG ($REF)…"

    if [ "$downloader" = "curl" ]; then
        curl -fsSL --retry 2 "$url" -o "$FETCH_DIR/src.tar.gz" \
            || die "download failed: $url"
    else
        wget -qO "$FETCH_DIR/src.tar.gz" "$url" \
            || die "download failed: $url"
    fi

    tar -xzf "$FETCH_DIR/src.tar.gz" -C "$FETCH_DIR" \
        || die "could not extract the downloaded archive"

    SRC_DIR="$(find "$FETCH_DIR" -maxdepth 2 -name shell.qml -printf '%h\n' 2>/dev/null | head -n 1)"
    [ -n "$SRC_DIR" ] || die "the downloaded archive does not contain shell.qml"
    ok "downloaded source"
}

resolve_local_source

# ---------------------------------------------------------------------------
# Dependency and compatibility checks
# ---------------------------------------------------------------------------

detect_qt_version() {
    local version=""

    if command -v qmake6 >/dev/null 2>&1; then
        version="$(qmake6 -query QT_VERSION 2>/dev/null || true)"
    fi
    if [ -z "$version" ] && command -v qtpaths6 >/dev/null 2>&1; then
        version="$(qtpaths6 --qt-query QT_VERSION 2>/dev/null || true)"
    fi
    if [ -z "$version" ] && command -v qml6 >/dev/null 2>&1; then
        version="$(qml6 --version 2>/dev/null | sed -n 's/.* \([0-9][0-9.]*\)$/\1/p')"
    fi
    if [ -z "$version" ] && command -v qml >/dev/null 2>&1; then
        version="$(qml --version 2>/dev/null | sed -n 's/.* \([0-9][0-9.]*\)$/\1/p')"
    fi

    printf '%s' "$version"
}

check_dependencies() {
    local missing=0
    say "Checking dependencies…"

    case "$(uname -s)" in
        Linux) ok "Linux detected ($(uname -r))" ;;
        *) fail "unsupported operating system: $(uname -s) (Linux is required)"; missing=1 ;;
    esac

    if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
        ok "Wayland session detected${WAYLAND_DISPLAY:+ ($WAYLAND_DISPLAY)}"
    else
        warn "no Wayland session detected — cheatshell needs wlr-layer-shell to run"
    fi

    case "${XDG_CURRENT_DESKTOP:-}" in
        *GNOME*|*gnome*)
            warn "GNOME/Mutter does not implement wlr-layer-shell; use niri, sway, Hyprland, KDE or another compatible compositor"
            ;;
    esac

    if command -v quickshell >/dev/null 2>&1; then
        local qs_version
        qs_version="$(quickshell --version 2>/dev/null | sed -n 's/^Quickshell \([0-9][0-9.]*\).*/\1/p')"
        if [ -z "$qs_version" ]; then
            warn "quickshell is installed but its version could not be read"
        elif version_ge "$qs_version" "0.3.2"; then
            ok "quickshell $qs_version"
        else
            fail "quickshell $qs_version is too old (need >= 0.3.2)"
            missing=1
        fi
    else
        fail "quickshell is not installed (need >= 0.3.2)"
        missing=1
    fi

    local qt_version
    qt_version="$(detect_qt_version)"
    if [ -n "$qt_version" ]; then
        if version_ge "$qt_version" "6.5"; then
            ok "Qt $qt_version"
        else
            fail "Qt $qt_version is too old (need >= 6.5)"
            missing=1
        fi
    else
        warn "Qt version not found (looked for qmake6/qtpaths6/qml6); continuing"
    fi

    local tool
    for tool in mkdir sed grep sort find tar; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            fail "required command missing: $tool"
            missing=1
        fi
    done

    if [ -z "$SRC_DIR" ]; then
        if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
            ok "downloader available"
        else
            fail "curl or wget is required for the one-liner installer"
            missing=1
        fi
    fi
    [ "$missing" -eq 0 ] && ok "core utilities present"

    if command -v qmllint >/dev/null 2>&1; then
        ok "qmllint available (syntax will be validated)"
    else
        warn "qmllint not found — skipping syntax validation"
    fi

    if command -v xdg-open >/dev/null 2>&1; then
        ok "xdg-open available (Ctrl+O)"
    else
        warn "xdg-open not found — Ctrl+O will not work"
    fi

    local editors=""
    local candidate
    for candidate in nvim vim code obsidian kitty alacritty ghostty foot wezterm; do
        if command -v "$candidate" >/dev/null 2>&1; then
            editors="${editors:+$editors, }$candidate"
        fi
    done
    if [ -n "$editors" ]; then
        ok "editors/terminals detected: $editors"
    else
        warn "no known editor or terminal found — configure behavior.openWith.command"
    fi

    if [ "$missing" -ne 0 ]; then
        say ""
        say "Install Quickshell >= 0.3.2 and Qt >= 6.5, then re-run this script."
        say "Packages: https://quickshell.org/docs/guide/install/"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

do_uninstall() {
    say "Uninstalling $APP_NAME from $TARGET_DIR"

    if [ ! -d "$TARGET_DIR" ]; then
        warn "nothing installed at $TARGET_DIR"
    else
        if [ "$ASSUME_YES" -ne 1 ]; then
            local answer=""
            if ask answer "Remove $TARGET_DIR? [y/N] " && [[ ! "$answer" =~ ^[yY]([eE][sS])?$ ]]; then
                say "Cancelled."
                exit 0
            fi
        fi
        if command -v qs >/dev/null 2>&1; then
            qs ipc -p "$TARGET_DIR" call "$APP_NAME" quit >/dev/null 2>&1 || true
        fi
        rm -rf -- "$TARGET_DIR"
        ok "removed $TARGET_DIR"
    fi

    if [ "$PURGE" -eq 1 ]; then
        if [ "$ASSUME_YES" -ne 1 ]; then
            local answer=""
            if ask answer "Also remove $CONFIG_DIR? [y/N] " && [[ ! "$answer" =~ ^[yY]([eE][sS])?$ ]]; then
                say "Kept $CONFIG_DIR"
                exit 0
            fi
        fi
        rm -rf -- "$CONFIG_DIR"
        ok "removed $CONFIG_DIR"
    else
        say "Kept your config at $CONFIG_FILE"
    fi
}

# ---------------------------------------------------------------------------
# Starter config
# ---------------------------------------------------------------------------

collect_notes_dir() {
    [ "$WRITE_CONFIG" -eq 1 ] || return 0
    [ -f "$CONFIG_FILE" ] && return 0

    local default="$NOTES_DIR"
    local answer=""

    if [ "$ASSUME_YES" -ne 1 ]; then
        if ask answer "Notes directory [$default]: "; then
            [ -n "$answer" ] && NOTES_DIR="$answer"
        fi
    fi

    NOTES_DIR="$(expand_path "$NOTES_DIR")"

    if [ -e "$NOTES_DIR" ] && [ ! -d "$NOTES_DIR" ]; then
        die "not a directory: $NOTES_DIR"
    fi

    if [ ! -d "$NOTES_DIR" ]; then
        if [ "$ASSUME_YES" -eq 1 ]; then
            mkdir -p -- "$NOTES_DIR"
            ok "created notes directory ($NOTES_DIR)"
        elif ask answer "Create $NOTES_DIR? [Y/n] "; then
            if [[ "$answer" =~ ^[nN]([oO])?$ ]]; then
                warn "notes directory does not exist yet — set it in Ctrl+, after launching"
            else
                mkdir -p -- "$NOTES_DIR"
                ok "created notes directory ($NOTES_DIR)"
            fi
        fi
    fi

    if [ -d "$NOTES_DIR" ]; then
        if [ -z "$(find "$NOTES_DIR" -name '*.md' -print -quit 2>/dev/null)" ]; then
            warn "no .md files in $NOTES_DIR yet"
        else
            ok "notes directory contains Markdown files"
        fi
    fi
}

write_starter_config() {
    [ "$WRITE_CONFIG" -eq 1 ] || return 0

    if [ -f "$CONFIG_FILE" ]; then
        ok "config already exists ($CONFIG_FILE)"
        return 0
    fi

    collect_notes_dir
    mkdir -p -- "$CONFIG_DIR"
    local stored_dir
    stored_dir="$(json_escape "$(config_path "$NOTES_DIR")")"

    cat > "$CONFIG_FILE" <<JSON
{
  "directories": [
    "$stored_dir"
  ],
  "recursive": true,
  "watch": true,
  "search": {
    "maxResults": 0,
    "pageSize": 30,
    "fuzzy": true,
    "minimumScore": 0
  },
  "indexing": {
    "maxFiles": 0
  },
  "behavior": {
    "copyOnEnter": true,
    "showPreview": true,
    "openSourceShortcut": true,
    "openWith": {
      "command": [
        "kitty",
        "nvim",
        "{path}"
      ]
    }
  },
  "appearance": {
    "windowWidth": 760,
    "windowHeight": 560
  }
}
JSON
    ok "wrote starter config ($CONFIG_FILE)"
}

validate_qml() {
    command -v qmllint >/dev/null 2>&1 || return 0

    local failed=0
    local file output

    for file in shell.qml config/*.qml services/*.qml components/*.qml models/*.qml; do
        if ! output="$( cd "$TARGET_DIR" && qmllint "$file" 2>&1 )"; then
            # Some qmllint builds exit non-zero without a diagnostic when they
            # do not understand a construct (for example inline components).
            if [ -n "$output" ]; then
                warn "QML issue in $file:"
                printf '%s\n' "$output" | sed 's/^/        /' | head -20
                failed=1
            fi
        fi
    done

    if [ "$failed" -eq 0 ]; then
        ok "QML syntax check passed"
    fi
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

do_install() {
    check_dependencies
    fetch_source

    [ -f "$SRC_DIR/shell.qml" ] || die "source is incomplete (shell.qml missing)"

    say ""
    say "Installing to $TARGET_DIR"

    if [ "$SRC_DIR" = "$TARGET_DIR" ]; then
        ok "already running from the install location — no files copied"
    else
        if [ -d "$TARGET_DIR" ] && [ "$ASSUME_YES" -ne 1 ]; then
            local answer=""
            if ask answer "Target exists. Overwrite installation files? [Y/n] " \
                    && [[ "$answer" =~ ^[nN]([oO])?$ ]]; then
                say "Cancelled."
                exit 0
            fi
        fi
        mkdir -p -- "$TARGET_DIR"
        # Copy the app without VCS metadata so the destination stays clean.
        ( cd "$SRC_DIR" && tar --exclude=.git -cf - . ) | ( cd "$TARGET_DIR" && tar -xf - )
        ok "copied application files"
    fi

    [ -f "$TARGET_DIR/shell.qml" ] || die "installation is incomplete (shell.qml missing)"

    write_starter_config
    validate_qml

    say ""
    say "Installed $APP_NAME"
    say ""
    say "Start it:"
    say "  quickshell -p \"$TARGET_DIR\""
    say ""
    say "Or keep one instance running and open it via IPC:"
    say "  qs ipc -p \"$TARGET_DIR\" call $APP_NAME toggle"
    say ""
    say "Suggested compositor bind (niri, ~/.config/niri/config.kdl):"
    say "  Mod+Shift+C { spawn \"qs\" \"ipc\" \"-p\" \"$TARGET_DIR\" \"call\" \"$APP_NAME\" \"toggle\"; }"
    say ""
    say "Notes: ${NOTES_DIR}"
    say "Config: $CONFIG_FILE"
    say ""
    say "Settings: Ctrl+,    Open in editor: Ctrl+E    Help: README.md"
}

if [ "$UNINSTALL" -eq 1 ]; then
    do_uninstall
else
    do_install
fi
