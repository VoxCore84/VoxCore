#!/usr/bin/env bash
# ==============================================================================
# DraconicBot — Deployment Script for Oracle Cloud / Ubuntu / Oracle Linux
#
# Usage:
#   chmod +x deploy.sh
#   sudo ./deploy.sh
#
# This script:
#   1. Detects OS (Ubuntu/Debian or Oracle Linux/RHEL)
#   2. Installs Python 3.12 + pip
#   3. Creates a 'draconic' system user
#   4. Copies bot files to /opt/draconic-bot/
#   5. Creates a virtualenv and installs requirements
#   6. Installs the systemd service
#   7. Enables and starts the bot
# ==============================================================================

set -euo pipefail

# --- Configuration ---
BOT_INSTALL_DIR="/opt/draconic-bot"
BOT_USER="draconic"
BOT_GROUP="draconic"
SERVICE_NAME="draconic"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT_SOURCE_DIR="$(dirname "$SCRIPT_DIR")"  # Parent of deploy/ = discord_bot/

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# --- Preflight ---
if [[ $EUID -ne 0 ]]; then
    fail "This script must be run as root (use sudo)."
fi

echo ""
echo "============================================"
echo "  DraconicBot Deployment Script"
echo "============================================"
echo ""

# --- Step 1: Detect OS and install Python 3.12 ---
info "Detecting operating system..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-0}"
else
    fail "Cannot detect OS — /etc/os-release not found."
fi

info "Detected: ${PRETTY_NAME:-$OS_ID $OS_VERSION}"

install_python_ubuntu() {
    info "Installing Python 3.12 on Ubuntu/Debian..."
    apt-get update -qq
    apt-get install -y -qq software-properties-common > /dev/null 2>&1

    # Python 3.12 is in the default repos for Ubuntu 24.04+
    # For older versions, use the deadsnakes PPA
    if ! apt-cache show python3.12 > /dev/null 2>&1; then
        info "Adding deadsnakes PPA for Python 3.12..."
        add-apt-repository -y ppa:deadsnakes/ppa > /dev/null 2>&1
        apt-get update -qq
    fi

    apt-get install -y -qq \
        python3.12 \
        python3.12-venv \
        python3.12-dev \
        python3-pip \
        > /dev/null 2>&1
    ok "Python 3.12 installed."
}

install_python_rhel() {
    info "Installing Python 3.12 on Oracle Linux/RHEL..."

    # Oracle Linux 9 / RHEL 9: Python 3.12 available via AppStream
    if command -v dnf > /dev/null 2>&1; then
        dnf install -y -q python3.12 python3.12-pip python3.12-devel 2>/dev/null || {
            # Fallback: enable CRB/EPEL if needed
            dnf install -y -q oracle-epel-release-el9 2>/dev/null || true
            dnf install -y -q python3.12 python3.12-pip python3.12-devel
        }
    elif command -v yum > /dev/null 2>&1; then
        yum install -y -q python3.12 python3.12-pip python3.12-devel 2>/dev/null || {
            yum install -y -q oracle-epel-release-el8 2>/dev/null || true
            yum install -y -q python3.12 python3.12-pip python3.12-devel
        }
    else
        fail "Neither dnf nor yum found — cannot install packages."
    fi
    ok "Python 3.12 installed."
}

case "$OS_ID" in
    ubuntu|debian|pop|linuxmint)
        install_python_ubuntu
        PYTHON_BIN="python3.12"
        ;;
    ol|rhel|centos|fedora|rocky|almalinux|amzn)
        install_python_rhel
        PYTHON_BIN="python3.12"
        ;;
    *)
        warn "Unrecognized OS '$OS_ID' — attempting generic Python 3.12 detection..."
        if command -v python3.12 > /dev/null 2>&1; then
            PYTHON_BIN="python3.12"
        elif command -v python3 > /dev/null 2>&1; then
            PYTHON_BIN="python3"
            warn "Using $(${PYTHON_BIN} --version) — Python 3.12+ recommended."
        else
            fail "Python 3 not found. Install Python 3.12 manually and re-run."
        fi
        ;;
esac

info "Python binary: $($PYTHON_BIN --version)"

# --- Step 2: Create bot user ---
info "Creating system user '${BOT_USER}'..."
if id "$BOT_USER" &>/dev/null; then
    ok "User '${BOT_USER}' already exists."
else
    groupadd --system "$BOT_GROUP" 2>/dev/null || true
    useradd --system --gid "$BOT_GROUP" --home-dir "$BOT_INSTALL_DIR" \
            --shell /usr/sbin/nologin "$BOT_USER"
    ok "User '${BOT_USER}' created."
fi

# --- Step 3: Copy bot files ---
info "Copying bot files to ${BOT_INSTALL_DIR}..."
mkdir -p "$BOT_INSTALL_DIR"

# Copy all bot source files (excluding deploy/, __pycache__, .env, logs/)
rsync -a --delete \
    --exclude='deploy/' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.env' \
    --exclude='logs/' \
    --exclude='run_bot.bat' \
    --exclude='start_bot.bat' \
    --exclude='stop_bot.bat' \
    --exclude='test_faq.py' \
    "$BOT_SOURCE_DIR/" "$BOT_INSTALL_DIR/"

# Create required directories
mkdir -p "$BOT_INSTALL_DIR/logs"
mkdir -p "$BOT_INSTALL_DIR/data"

ok "Bot files copied."

# --- Step 4: Set up .env ---
if [ ! -f "$BOT_INSTALL_DIR/.env" ]; then
    if [ -f "$BOT_SOURCE_DIR/.env" ]; then
        warn "Copying .env from source. REVIEW AND EDIT secrets before starting!"
        cp "$BOT_SOURCE_DIR/.env" "$BOT_INSTALL_DIR/.env"
    else
        warn "No .env file found — copying .env.example as template."
        cp "$BOT_INSTALL_DIR/.env.example" "$BOT_INSTALL_DIR/.env"
        warn ">>> EDIT ${BOT_INSTALL_DIR}/.env with your Discord token before starting! <<<"
    fi
    chmod 600 "$BOT_INSTALL_DIR/.env"
else
    info ".env already exists at ${BOT_INSTALL_DIR}/.env — not overwriting."
fi

# --- Step 5: Create virtualenv and install requirements ---
info "Setting up Python virtualenv..."
$PYTHON_BIN -m venv "$BOT_INSTALL_DIR/venv"
"$BOT_INSTALL_DIR/venv/bin/pip" install --upgrade pip > /dev/null 2>&1
"$BOT_INSTALL_DIR/venv/bin/pip" install --no-cache-dir -r "$BOT_INSTALL_DIR/requirements.txt"
ok "Python dependencies installed."

# --- Step 6: Fix ownership ---
info "Setting file ownership..."
chown -R "$BOT_USER:$BOT_GROUP" "$BOT_INSTALL_DIR"
ok "Ownership set to ${BOT_USER}:${BOT_GROUP}."

# --- Step 7: Install systemd service ---
info "Installing systemd service..."
cp "$SCRIPT_DIR/draconic.service" /etc/systemd/system/draconic.service
systemctl daemon-reload
ok "Systemd service installed."

# --- Step 8: Enable and start ---
info "Enabling and starting ${SERVICE_NAME}..."
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# Brief pause to let it start
sleep 3

# --- Step 9: Show status ---
echo ""
echo "============================================"
echo "  Deployment Complete"
echo "============================================"
echo ""
systemctl status "$SERVICE_NAME" --no-pager -l || true

echo ""
info "Useful commands:"
echo "  View logs:      journalctl -u ${SERVICE_NAME} -f"
echo "  Restart:        sudo systemctl restart ${SERVICE_NAME}"
echo "  Stop:           sudo systemctl stop ${SERVICE_NAME}"
echo "  Check status:   sudo systemctl status ${SERVICE_NAME}"
echo "  Edit config:    sudo nano ${BOT_INSTALL_DIR}/.env"
echo "  Update bot:     rsync files, then: sudo systemctl restart ${SERVICE_NAME}"
echo ""

# --- Final check ---
if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "DraconicBot is running!"
else
    warn "Service may not have started. Check: journalctl -u ${SERVICE_NAME} -e"
    warn "Most common cause: DISCORD_TOKEN not set in ${BOT_INSTALL_DIR}/.env"
fi
