# AGY Remote Docker Sandbox

A high-privilege Docker sandbox for the Antigravity CLI (`agy`) with full host access and remote control enabled.

## Features

- **Host Authority & Privileges**: Runs in `--privileged` mode with host network (`--net=host`), host PID (`--pid=host`), host root filesystem (`-v /:/host`), and host Docker socket (`-v /var/run/docker.sock`).
- **Autonomous Execution**: Runs with `--dangerously-skip-permissions` so commands and tools execute without interactive confirmation.
- **Remote Control**: Enabled automatically (`--remote-control`), outputting a web takeover link.
- **Global CLI Shortcut**: Use `/agy_remote` or `agy_remote` anywhere in the terminal to interact with the container.

---

## Quick Usage

### 1. Interactive Menu
Run the script without arguments for an interactive menu:
```bash
./agy_remote.sh
```

### 2. Command Line Arguments
```bash
# Install dependencies, build Docker image, and set up /agy_remote
./agy_remote.sh install

# Sign-in / Authenticate with Google OAuth (run in a fresh Codespace)
./agy_remote.sh login

# Start the sandbox container in the background
./agy_remote.sh run

# Check sandbox status and retrieve the active Remote Control URL
./agy_remote.sh status

# Stop and remove the sandbox container
./agy_remote.sh stop

# Restart the sandbox container
./agy_remote.sh restart

# View sandbox logs (pass -f to follow live)
./agy_remote.sh logs
./agy_remote.sh logs -f

# Open interactive root shell inside container with full host access
./agy_remote.sh shell
```

---

## CLI Access (`/agy_remote`)

Once installed, you can use `/agy_remote` or `agy_remote` directly from any terminal:

```bash
# Open interactive AGY session inside sandbox
/agy_remote

# Run a non-interactive prompt
/agy_remote -p "ping"

# Attach directly to the background remote-control session
/agy_remote --attach

# Open root bash shell with full host access
/agy_remote --shell
```
