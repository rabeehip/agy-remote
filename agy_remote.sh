#!/usr/bin/env bash
# ==============================================================================
# AGY REMOTE SANDBOX MANAGER
# Full Authority & Host Access Docker Sandbox for Antigravity CLI (agy)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="agy_sandbox"
IMAGE_NAME="agy-sandbox:latest"
WORKSPACE_DIR="/workspaces"
TARGET_DIR="/workspaces/Home"
HOST_AGY_BIN="$(which agy 2>/dev/null || echo "/home/codespace/.local/bin/agy")"
HOST_GEMINI_DIR="${HOME}/.gemini"
CLI_WRAPPER="/usr/local/bin/agy_remote"
CLI_ROOT_LINK="/agy_remote"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Robust binary discovery for agy
find_agy_bin() {
    if [ -n "${HOST_AGY_BIN}" ] && [ -x "${HOST_AGY_BIN}" ]; then
        return 0
    fi
    HOST_AGY_BIN="$(command -v agy 2>/dev/null || true)"
    if [ -z "${HOST_AGY_BIN}" ]; then
        for candidate in "${HOME}/.local/bin/agy" "/home/codespace/.local/bin/agy" "/usr/local/bin/agy" "/usr/bin/agy"; do
            if [ -x "${candidate}" ]; then
                HOST_AGY_BIN="${candidate}"
                break
            fi
        done
    fi
}

# Fix file permissions across host .gemini directory to prevent permission denied errors
fix_permissions() {
    if [ -d "${HOST_GEMINI_DIR}" ]; then
        sudo chown -R "$(id -u):$(id -g)" "${HOST_GEMINI_DIR}" 2>/dev/null || true
        sudo chmod -R 777 "${HOST_GEMINI_DIR}" 2>/dev/null || true
    fi
    if [ -d "${SCRIPT_DIR}" ]; then
        sudo chown -R "$(id -u):$(id -g)" "${SCRIPT_DIR}" 2>/dev/null || true
    fi
}

# Pre-seed onboarding and Terms of Service acceptance to avoid blocking prompts & permission issues
seed_onboarding() {
    local AGY_DIR="${HOST_GEMINI_DIR}/antigravity-cli"
    mkdir -p "${AGY_DIR}/cache" "${AGY_DIR}/log" "${AGY_DIR}/conversations" 2>/dev/null || true

    # Force complete onboarding flags
    cat << 'EOF' > "${AGY_DIR}/cache/onboarding.json"
{
  "consumerOnboardingComplete": true,
  "enterpriseOnboardingComplete": false,
  "onboardingComplete": true
}
EOF

    # Force complete state and migration flags in jetski_state.pbtxt
    cat << 'EOF' > "${AGY_DIR}/jetski_state.pbtxt"
post_onboarding: {
  completed_steps: POST_ONBOARDING_STEP_TYPE_MANAGER_WELCOME
  completed_steps: POST_ONBOARDING_STEP_TYPE_USAGE_MODE
  completed_steps: POST_ONBOARDING_STEP_TYPE_AGENT_CONFIGURATION
  completed_steps: POST_ONBOARDING_STEP_TYPE_ADD_WORKSPACE
}
installation_uuid: "537c4003-1ea7-4ece-acf8-5b8459490ce9"
migrations: {
  key: 3
  value: MIGRATION_STATUS_COMPLETED
}
migrations: {
  key: 4
  value: MIGRATION_STATUS_COMPLETED
}
migrations: {
  key: 5
  value: MIGRATION_STATUS_COMPLETED
}
EOF

    if [ ! -f "${AGY_DIR}/installation_id" ]; then
        echo "537c4003-1ea7-4ece-acf8-5b8459490ce9" > "${AGY_DIR}/installation_id"
    fi

    if [ ! -f "${AGY_DIR}/settings.json" ]; then
        cat << 'EOF' > "${AGY_DIR}/settings.json"
{
  "trustedWorkspaces": [
    "/workspaces",
    "/workspaces/Home"
  ]
}
EOF
    fi

    fix_permissions
}

# ------------------------------------------------------------------------------
# Command: install
# Installs requirements, docker (if missing), builds sandbox image, and sets up /agy_remote
# ------------------------------------------------------------------------------
do_install() {
    echo -e "${BOLD}${BLUE}=== Installing AGY Remote Sandbox Requirements ===${NC}"
    
    # 0. Pre-seed Onboarding & Permissions
    seed_onboarding
    fix_permissions
    find_agy_bin

    # 1. Check & Install Docker
    if ! command -v docker &>/dev/null; then
        print_info "Docker is not installed. Installing docker.io..."
        sudo apt-get update && sudo apt-get install -y docker.io
        sudo systemctl enable --now docker 2>/dev/null || sudo service docker start 2>/dev/null || true
        print_success "Docker installed successfully."
    else
        print_success "Docker is already installed ($(docker --version))."
    fi

    # 2. Verify Docker service is accessible
    if ! docker info &>/dev/null; then
        print_warn "Docker service is not responding. Attempting to start service..."
        sudo service docker start 2>/dev/null || sudo systemctl start docker 2>/dev/null || true
        sleep 2
        if ! docker info &>/dev/null; then
            print_error "Unable to connect to Docker daemon. Please ensure docker is running."
            exit 1
        fi
    fi

    # 3. Check & Install Antigravity CLI (agy)
    find_agy_bin
    if [ -z "${HOST_AGY_BIN}" ] || [ ! -f "${HOST_AGY_BIN}" ]; then
        print_info "Antigravity CLI ('agy') not found. Installing via 'curl -fsSL https://antigravity.google/cli/install.sh | bash'..."
        curl -fsSL https://antigravity.google/cli/install.sh | bash
        export PATH="${HOME}/.local/bin:${PATH}"
        find_agy_bin
        if [ -z "${HOST_AGY_BIN}" ] || [ ! -f "${HOST_AGY_BIN}" ]; then
            print_error "Failed to install Antigravity CLI. Please verify internet access and retry."
            exit 1
        fi
        print_success "Antigravity CLI installed successfully at: ${HOST_AGY_BIN}"
    else
        print_success "Found Antigravity CLI binary at: ${HOST_AGY_BIN}"
    fi

    # 4. Build Sandbox Docker Image
    print_info "Building Docker Sandbox Image '${IMAGE_NAME}'..."
    if [ -f "${SCRIPT_DIR}/Dockerfile" ]; then
        docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
        print_success "Docker image '${IMAGE_NAME}' built successfully."
    else
        print_error "Dockerfile not found at ${SCRIPT_DIR}/Dockerfile"
        exit 1
    fi

    # 5. Create CLI Access Wrapper Script
    print_info "Configuring CLI access at ${CLI_WRAPPER} and ${CLI_ROOT_LINK}..."
    sudo tee "${CLI_WRAPPER}" > /dev/null << 'EOF'
#!/usr/bin/env bash
CONTAINER_NAME="agy_sandbox"
SCRIPT_PATH="/workspaces/Home/AGY REMOTE/agy_remote.sh"

# Ensure container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[!] Sandbox container '${CONTAINER_NAME}' is not running."
    echo "[*] Starting sandbox container automatically..."
    if [ -f "${SCRIPT_PATH}" ]; then
        bash "${SCRIPT_PATH}" run
    else
        echo "[-] Could not find ${SCRIPT_PATH} to auto-start container."
        exit 1
    fi
fi

# Dispatch based on arguments
if [ $# -eq 0 ]; then
    # Launch interactive agy session with full permissions
    exec docker exec -it "${CONTAINER_NAME}" agy --dangerously-skip-permissions
elif [ "$1" = "--attach" ] || [ "$1" = "-a" ]; then
    # Attach directly to the running remote-control daemon session
    echo "[*] Attaching to live remote-control daemon session (Detach with Ctrl+P, Ctrl+Q)..."
    exec docker attach "${CONTAINER_NAME}"
elif [ "$1" = "--shell" ] || [ "$1" = "-s" ]; then
    # Open root bash shell with full host authority
    exec docker exec -it "${CONTAINER_NAME}" bash
else
    # Execute command directly with agy
    exec docker exec -it "${CONTAINER_NAME}" agy --dangerously-skip-permissions "$@"
fi
EOF

    sudo chmod +x "${CLI_WRAPPER}"
    sudo ln -sf "${CLI_WRAPPER}" "${CLI_ROOT_LINK}"

    # 6. Check Authentication Token
    seed_onboarding
    fix_permissions
    if [ ! -f "${HOST_GEMINI_DIR}/antigravity-cli/antigravity-oauth-token" ]; then
        echo ""
        print_warn "No Antigravity login token found at ${HOST_GEMINI_DIR}/antigravity-cli/antigravity-oauth-token"
        print_info "To use Remote Control, you need to authenticate with Google."
        print_info "Run '${SCRIPT_DIR}/agy_remote.sh login' or type 'agy' to log in."
        echo ""
    else
        print_success "Existing Antigravity authentication token detected."
    fi

    fix_permissions
    print_success "Installation complete! You can now run '${SCRIPT_DIR}/agy_remote.sh run' or use '/agy_remote'."
}

# ------------------------------------------------------------------------------
# Command: login
# Launches interactive login to authenticate with Google Antigravity
# ------------------------------------------------------------------------------
do_login() {
    echo -e "${BOLD}${BLUE}=== Antigravity CLI Authentication / Login ===${NC}"
    fix_permissions
    seed_onboarding
    print_info "Launching interactive authentication..."
    print_info "Follow the on-screen instructions or URL to complete Google sign-in."
    echo ""
    if [ -x "${HOST_AGY_BIN}" ]; then
        "${HOST_AGY_BIN}"
    else
        # If running from inside container
        docker exec -it "${CONTAINER_NAME}" agy
    fi
    fix_permissions
}

# ------------------------------------------------------------------------------
# Command: run (start)
# Starts the privileged sandbox container in background with full authority
# ------------------------------------------------------------------------------
do_run() {
    echo -e "${BOLD}${BLUE}=== Starting AGY Remote Sandbox Container ===${NC}"
    find_agy_bin
    seed_onboarding
    fix_permissions
    
    # Check if already running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_warn "Container '${CONTAINER_NAME}' is already running."
        do_status
        return 0
    fi

    # Remove stopped container if exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_info "Removing stopped container instance '${CONTAINER_NAME}'..."
        docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    fi

    # Ensure image exists
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
        print_warn "Image '${IMAGE_NAME}' not found. Triggering install/build..."
        do_install
    fi

    # Check if login token exists, if not, guide user through login directly
    if [ ! -f "${HOST_GEMINI_DIR}/antigravity-cli/antigravity-oauth-token" ]; then
        echo ""
        print_warn "No Google Antigravity login token detected!"
        print_info "A quick Google login is required to initialize Remote Control."
        echo ""
        do_login
        fix_permissions
        if [ ! -f "${HOST_GEMINI_DIR}/antigravity-cli/antigravity-oauth-token" ]; then
            print_error "Login was not completed. Please authenticate to start Remote Control."
            exit 1
        fi
    fi

    # Ensure gemini settings trust target workspace
    if [ -f "${HOST_GEMINI_DIR}/antigravity-cli/settings.json" ]; then
        if ! grep -q "${TARGET_DIR}" "${HOST_GEMINI_DIR}/antigravity-cli/settings.json"; then
            print_info "Adding ${TARGET_DIR} to trusted workspaces..."
        fi
    fi

    print_info "Launching privileged sandbox container with full host authority..."
    docker run -dt \
        --name "${CONTAINER_NAME}" \
        --restart unless-stopped \
        --privileged \
        --net=host \
        --pid=host \
        --ipc=host \
        -v /:/host \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "${WORKSPACE_DIR}":"${WORKSPACE_DIR}" \
        -v "${HOST_GEMINI_DIR}":/root/.gemini \
        -v "${HOST_GEMINI_DIR}":/home/codespace/.gemini \
        -v "${HOST_AGY_BIN}":/usr/local/bin/agy:ro \
        -w "${TARGET_DIR}" \
        "${IMAGE_NAME}" \
        agy --remote-control --dangerously-skip-permissions

    print_success "Container '${CONTAINER_NAME}' started successfully in background."
    print_info "Waiting for Remote Control connection link..."
    
    # Wait up to 5 seconds to inspect logs for remote control URL
    sleep 3
    fix_permissions
    echo ""
    echo -e "${BOLD}${GREEN}------------------------------------------------------------${NC}"
    echo -e "${BOLD}AGY Remote Control Status:${NC}"
    REMOTE_URL=$(docker logs "${CONTAINER_NAME}" 2>&1 | grep -o 'https://antigravity.google.com/r/[a-zA-Z0-9_-]*' | tail -n 1 || true)
    HOSTNAME_VAL=$(docker logs "${CONTAINER_NAME}" 2>&1 | grep 'Hostname:' | tail -n 1 || true)
    
    if [ -n "${REMOTE_URL}" ]; then
        [ -n "${HOSTNAME_VAL}" ] && echo -e "  ${BOLD}${HOSTNAME_VAL}${NC}"
        echo -e "  Connect URL: ${CYAN}${REMOTE_URL}${NC}"
    else
        echo -e "  ${YELLOW}Initializing session... Run '${CLI_ROOT_LINK}' or check logs below.${NC}"
    fi
    echo -e "${BOLD}${GREEN}------------------------------------------------------------${NC}"
    echo ""
    print_info "You can interact with AGY anytime using: ${BOLD}${CLI_ROOT_LINK}${NC} or ${BOLD}agy_remote${NC}"
}

# ------------------------------------------------------------------------------
# Command: status
# ------------------------------------------------------------------------------
do_status() {
    echo -e "${BOLD}${BLUE}=== AGY Remote Sandbox Status ===${NC}"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        STATUS_INFO=$(docker ps --filter "name=^${CONTAINER_NAME}$" --format "ID: {{.ID}} | Status: {{.Status}} | Ports: {{.Ports}}")
        echo -e "  State:     ${GREEN}${BOLD}RUNNING${NC}"
        echo -e "  Details:   ${STATUS_INFO}"
        
        # Check remote control URL
        REMOTE_URL=$(docker logs "${CONTAINER_NAME}" 2>&1 | grep -o 'https://antigravity.google.com/r/[a-zA-Z0-9_-]*' | tail -n 1 || true)
        HOSTNAME_VAL=$(docker logs "${CONTAINER_NAME}" 2>&1 | grep 'Hostname:' | tail -n 1 || true)
        if [ -n "${REMOTE_URL}" ]; then
            [ -n "${HOSTNAME_VAL}" ] && echo -e "  Instance:  ${HOSTNAME_VAL}"
            echo -e "  Remote:    ${CYAN}${REMOTE_URL}${NC}"
        fi
        
        echo -e "  CLI Path:  ${BOLD}${CLI_ROOT_LINK}${NC} (or ${CLI_WRAPPER})"
    else
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo -e "  State:     ${YELLOW}${BOLD}STOPPED${NC}"
        else
            echo -e "  State:     ${RED}${BOLD}NOT CREATED${NC}"
        fi
        echo -e "  Run '${SCRIPT_DIR}/agy_remote.sh run' to launch the sandbox."
    fi
}

# ------------------------------------------------------------------------------
# Command: stop
# ------------------------------------------------------------------------------
do_stop() {
    echo -e "${BOLD}${YELLOW}=== Stopping AGY Remote Sandbox Container ===${NC}"
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
        docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
        print_success "Container '${CONTAINER_NAME}' stopped and removed."
    else
        print_warn "Container '${CONTAINER_NAME}' is not running."
    fi
}

# ------------------------------------------------------------------------------
# Command: restart
# ------------------------------------------------------------------------------
do_restart() {
    do_stop
    sleep 1
    do_run
}

# ------------------------------------------------------------------------------
# Command: logs
# ------------------------------------------------------------------------------
do_logs() {
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_error "Container '${CONTAINER_NAME}' does not exist. Run it first with 'run'."
        exit 1
    fi

    if [ "$1" = "-f" ] || [ "$1" = "--follow" ]; then
        docker logs -f "${CONTAINER_NAME}"
    else
        docker logs --tail 50 "${CONTAINER_NAME}"
    fi
}

# ------------------------------------------------------------------------------
# Command: cli
# ------------------------------------------------------------------------------
do_cli() {
    if [ -x "${CLI_WRAPPER}" ]; then
        exec "${CLI_WRAPPER}" "$@"
    else
        print_info "CLI launcher not found, executing directly via docker..."
        exec docker exec -it "${CONTAINER_NAME}" agy --dangerously-skip-permissions "$@"
    fi
}

# ------------------------------------------------------------------------------
# Command: shell
# ------------------------------------------------------------------------------
do_shell() {
    print_info "Opening interactive root shell in sandbox with host authority..."
    exec docker exec -it "${CONTAINER_NAME}" bash
}

# ------------------------------------------------------------------------------
# Command: update
# Updates Antigravity CLI binary and rebuilds sandbox Docker container
# ------------------------------------------------------------------------------
do_update() {
    echo -e "${BOLD}${BLUE}=== Updating AGY Remote & Sandbox ===${NC}"
    
    # 1. Update Antigravity CLI on Host
    print_info "Checking for Antigravity CLI updates..."
    if [ -x "${HOST_AGY_BIN}" ]; then
        "${HOST_AGY_BIN}" update || true
    else
        print_info "Installing Antigravity CLI via official script..."
        curl -fsSL https://antigravity.google/cli/install.sh | bash
    fi

    # 2. Rebuild Docker Image if needed
    print_info "Rebuilding Sandbox Docker image '${IMAGE_NAME}'..."
    if [ -f "${SCRIPT_DIR}/Dockerfile" ]; then
        docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
        print_success "Docker image '${IMAGE_NAME}' is up to date."
    fi

    # 3. Restart container if currently running to apply changes
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_info "Container '${CONTAINER_NAME}' is running. Restarting to apply updates..."
        do_restart
    else
        print_success "Update complete."
    fi
}

# ------------------------------------------------------------------------------
# Command: help
# ------------------------------------------------------------------------------
do_help() {
    echo -e "${BOLD}AGY Remote Sandbox Manager${NC}"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Available commands:"
    echo "  install      Install requirements, Docker image, and setup /agy_remote CLI"
    echo "  login        Authenticate / Sign-in to Antigravity CLI via Google OAuth"
    echo "  run | start  Start sandbox container with full host authority and remote control"
    echo "  status       Display current container status and remote control URL"
    echo "  stop         Stop and clean up sandbox container"
    echo "  restart      Restart the sandbox container"
    echo "  logs [-f]    Display container logs (pass -f to follow)"
    echo "  update       Update Antigravity CLI and rebuild sandbox container"
    echo "  cli [...]    Launch interactive AGY session or run command with skipped permissions"
    echo "  shell        Open root bash shell inside container with full host authority"
    echo "  help         Show this help screen"
    echo ""
    echo "CLI Shortcut:"
    echo "  /agy_remote         Direct CLI entrypoint anywhere on system"
}

# ------------------------------------------------------------------------------
# Interactive Menu (when invoked without arguments)
# ------------------------------------------------------------------------------
interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${BLUE}============================================================${NC}"
        echo -e "${BOLD}${CYAN}               AGY REMOTE SANDBOX MANAGER                   ${NC}"
        echo -e "${BOLD}${BLUE}============================================================${NC}"
        echo ""
        do_status
        echo ""
        echo -e "${BOLD}Select an action:${NC}"
        echo "  1) Install Requirements & Setup CLI"
        echo "  2) Authenticate / Login (Google OAuth)"
        echo "  3) Run / Start Sandbox (with Remote Control)"
        echo "  4) Show Status & Remote Link"
        echo "  5) View Logs (Last 50 lines)"
        echo "  6) Follow Logs (Real-time)"
        echo "  7) Open AGY CLI (/agy_remote)"
        echo "  8) Open Root Shell in Sandbox"
        echo "  9) Update AGY & Sandbox"
        echo "  10) Stop Sandbox"
        echo "  11) Restart Sandbox"
        echo "  0) Exit"
        echo ""
        read -rp "Enter choice [0-11]: " choice
        echo ""
        case "$choice" in
            1) do_install ;;
            2) do_login ;;
            3) do_run ;;
            4) do_status ;;
            5) do_logs ;;
            6) do_logs -f ;;
            7) do_cli ;;
            8) do_shell ;;
            9) do_update ;;
            10) do_stop ;;
            11) do_restart ;;
            0) exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
        echo ""
        read -rp "Press [Enter] to continue..." _
    done
}

# ------------------------------------------------------------------------------
# Main Dispatcher
# ------------------------------------------------------------------------------
case "$1" in
    install)
        shift
        do_install "$@"
        ;;
    login)
        shift
        do_login "$@"
        ;;
    run|start)
        shift
        do_run "$@"
        ;;
    status)
        shift
        do_status "$@"
        ;;
    stop)
        shift
        do_stop "$@"
        ;;
    restart)
        shift
        do_restart "$@"
        ;;
    logs)
        shift
        do_logs "$@"
        ;;
    update)
        shift
        do_update "$@"
        ;;
    cli)
        shift
        do_cli "$@"
        ;;
    shell)
        shift
        do_shell "$@"
        ;;
    help|--help|-h)
        do_help
        ;;
    "")
        interactive_menu
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        do_help
        exit 1
        ;;
esac
