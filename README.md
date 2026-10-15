# AGY Remote Docker Sandbox

A high-privilege Docker sandbox for the **Google Antigravity CLI (`agy`)** designed for cloud dev environments (GitHub Codespaces, Linux VMs, and remote workstations) with full host authority, autonomous tool execution, and Remote Control enabled.

---

## ⚡ Quickstart (Fresh Codespace)

Get up and running in under a minute in any fresh environment:

```bash
# 1. Clone the repository
git clone https://github.com/rabeehip/agy-remote.git
cd agy-remote

# 2. Install requirements & prepare the environment
./agy_remote.sh install

# 3. Start the sandbox (auto-prompts login if needed)
./agy_remote.sh run
```

> **Note**: If `agy` is not already installed on the host machine, `install` automatically downloads and configures it via `curl -fsSL https://antigravity.google/cli/install.sh | bash`.
> 
> If you haven't authenticated with Google yet, `./agy_remote.sh run` automatically triggers the Google OAuth sign-in flow, saves the credentials, and immediately launches your Remote Control session.

---

## 🌟 Key Features

- **Full Host Authority**:
  - `--privileged` container execution.
  - **Host Filesystem**: Mounted at `/host` (full read, write, and execute authority across the entire host).
  - **Host Docker Daemon**: Mounted via `/var/run/docker.sock` (manage, inspect, and spawn host containers).
  - **Host Network & PID**: `--net=host`, `--pid=host`, `--ipc=host`.
- **Autonomous Execution (`--dangerously-skip-permissions`)**:
  - Tool calls, bash executions, and file edits run automatically without waiting for interactive user approvals.
- **Remote Control Daemon**:
  - Automatically launches with `--remote-control`, generating a live web takeover link (`https://antigravity.google.com/r/...`).
- **Zero Permission Conflicts**:
  - Automatically manages file ownership and permissions (`chmod 777` on `~/.gemini`) so root-level background processes never lock out non-root host users.
- **Pre-Seeded Onboarding**:
  - Pre-configures Terms of Service acceptance and workspace trust (`/workspaces`), bypassing repetitive onboarding modals.
- **Automatic Self-Updating**:
  - Built-in `update` command keeps both the host `agy` binary and the container image up to date.
- **Global CLI Shortcut**:
  - Interactively control the sandbox from anywhere on the system via `/agy_remote` or `agy_remote`.

---

## 🌐 Remote Control & Web Interface

When you run `./agy_remote.sh run` (or `./agy_remote.sh status`), the script displays a unique connection URL:

```text
Connect URL: https://antigravity.google.com/r/xxxx-xxxx-xxxx-xxxx
```

- **Open on Any Device**: Paste the link into any browser (laptop, phone, tablet) to take control of your Codespace agent remotely.
- **Real-Time Code Execution**: Prompt the agent to write code, install libraries, create files, or run tests while you watch live outputs.
- **No Extra Software Required**: The web interface connects directly through Google's secure Remote Control relay.

---

## 🛠️ Management Commands

You can run commands directly or launch the interactive menu:

### Interactive Menu
Run without arguments to access the menu:
```bash
./agy_remote.sh
```

### Command Line Options

| Command | Action |
| :--- | :--- |
| `./agy_remote.sh install` | Installs Antigravity CLI via `curl -fsSL https://antigravity.google/cli/install.sh \| bash` (if missing), verifies Docker, builds the sandbox image, pre-seeds onboarding, and configures `/agy_remote`. |
| `./agy_remote.sh login` | Triggers Google OAuth sign-in and saves credentials to host & container. |
| `./agy_remote.sh run` | Launches the privileged container in the background and prints the Remote Control URL. |
| `./agy_remote.sh status` | Checks container status, uptime, instance name, and prints the live Remote Control URL. |
| `./agy_remote.sh stop` | Gracefully stops and cleans up the container. |
| `./agy_remote.sh restart` | Restarts the container and generates a fresh connection session. |
| `./agy_remote.sh update` | Checks for `agy` updates, rebuilds the container image, and restarts the sandbox. |
| `./agy_remote.sh perms` | Manually synchronizes ownership and `chmod 777` permissions across `~/.gemini`. |
| `./agy_remote.sh uninstall` | Completely removes Docker container, image, CLI wrappers, host binary, and all `~/.gemini` data without leaving a trace (add `-y` for non-interactive). |
| `./agy_remote.sh logs` | Displays the last 50 lines of logs. Add `-f` to follow live (`./agy_remote.sh logs -f`). |
| `./agy_remote.sh shell` | Spawns an interactive root bash shell inside the container with host access. |
| `./agy_remote.sh cli` | Runs an interactive Antigravity CLI session inside the container. |

---

## 💻 CLI Access (`/agy_remote`)

Once installed, [`/agy_remote`](file:///agy_remote) is globally available anywhere on your machine:

```bash
# Open interactive AGY session inside the container
/agy_remote

# Run autonomous tasks non-interactively
/agy_remote -p "Run 'docker ps' and 'df -h' and summarize system state"

# Attach directly to the running Remote Control daemon session
/agy_remote --attach

# Open a root shell inside the sandbox with full host privileges
/agy_remote --shell
```

---

## 🐳 Docker Compose Alternative

If you prefer using Docker Compose directly instead of the helper script:

```bash
# Build the sandbox image
docker compose build

# Start in detached mode
docker compose up -d

# View logs and retrieve the Remote Control link
docker compose logs -f
```

---

## 🔄 Self-Healing & Permissions

When Docker containers run as `root` with mounted host volumes, files written to `~/.gemini` can normally cause `permission denied` errors for host users. 

**AGY Remote automatically handles this:**
1. **Pre-Seeded State**: Injects `onboardingComplete` and migration states into `jetski_state.pbtxt` and `cache/onboarding.json` so you never get trapped in Terms of Service onboarding prompts.
2. **Permission Synchronization**: Before and after every action (`run`, `install`, `login`, `update`), the script synchronizes ownership and `chmod 777` permissions across `~/.gemini`.
3. **Always-On Daemon**: Built with Docker restart policy `unless-stopped` so your session persists across machine restarts and daemon reboots.

---

## ❓ Troubleshooting & FAQs

### How do I find my Remote Control URL if I close the terminal?
Run:
```bash
./agy_remote.sh status
```
Or inspect the logs directly:
```bash
docker logs agy_sandbox 2>&1 | grep "https://antigravity.google.com/r/"
```

### What if my Google authentication token expires?
Run the built-in login command:
```bash
./agy_remote.sh login
```
Then restart the container with `./agy_remote.sh restart`.

### How do I update to the newest Antigravity CLI build?
Simply run:
```bash
./agy_remote.sh update
```
This updates the binary, rebuilds the Docker container, and reloads the sandbox.

---

## ⚠️ Security Notice

This sandbox is configured for **full authority** and **autonomous execution**:
- It runs in `--privileged` mode with access to the host's `/` filesystem and Docker socket `/var/run/docker.sock`.
- It executes with `--dangerously-skip-permissions`.

This setup is ideal for disposable cloud developer sandboxes (like GitHub Codespaces) where you want an AI pair programmer with unrestricted capabilities, but should be used with appropriate care on shared or production systems.

---

## 📂 Repository Structure

- [`agy_remote.sh`](agy_remote.sh): All-in-one management script and menu.
- [`Dockerfile`](Dockerfile): Hardened Ubuntu container with CA certificates, Docker CLI, and development tools.
- [`docker-compose.yml`](docker-compose.yml): Privileged Docker Compose service specification.
- [`README.md`](README.md): Documentation and operational guide.
- [`.gitignore`](.gitignore): Clean exclusion of logs and temporary artifacts.
