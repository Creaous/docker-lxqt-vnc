# Docker LXQT VNC

A lightweight Docker container providing a complete LXQT desktop environment accessible via VNC with the Papirus icon theme.

## Features

- Arch Linux base with LXQT desktop environment
- TigerVNC server for remote access
- Papirus icon theme with proper Qt5 integration
- Complete desktop applications (file manager, terminal, image viewer)
- Custom user support with configurable sudo access
- D-Bus integration for proper desktop functionality

## Quick Start

### Build and Run
```bash
# Build the container
docker build -t lxqt-vnc .

# Run with default settings (root user, password: "password")
docker run -d -p 5901:5901 --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE lxqt-vnc

# Connect with VNC client to localhost:5901
```

### Custom User Setup
```bash
# Run with custom user and password
docker run -d -p 5901:5901 \
  -e VNC_USER=myuser \
  -e VNC_PASSWORD=mypassword \
  --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE \
  lxqt-vnc
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VNC_USER` | `root` | Username for VNC connection |
| `VNC_PASSWORD` | `password` | Password for VNC connection |
| `SUDO_NOPASSWD` | `false` | Allow passwordless sudo for custom users |

## Usage Examples

### Development Environment
```bash
docker run -d --name dev-desktop \
  -p 5901:5901 \
  -e VNC_USER=developer \
  -e VNC_PASSWORD=dev123 \
  -e SUDO_NOPASSWD=true \
  -v $(pwd)/workspace:/home/developer/workspace \
  --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE \
  lxqt-vnc
```

### Docker Compose
```yaml
services:
  lxqt-desktop:
    build: .
    ports:
      - "5901:5901"
    environment:
      - VNC_USER=developer
      - VNC_PASSWORD=devpass123
      - SUDO_NOPASSWD=true
    volumes:
      - ./workspace:/home/developer/workspace
    cap_add:
      - SYS_ADMIN
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    restart: unless-stopped
```

## Included Applications

- **QTerminal** - Terminal emulator
- **PCManFM-Qt** - File manager with icon support
- **LXImage-Qt** - Image viewer and screenshot tool
- **LXQt Runner** - Application launcher (Alt+F2)
- **QPS** - Process manager
- **LXQt Configuration Center** - System settings

## Custom Scripts

Mount custom scripts to `/entrypoint.d/` to run during container startup. Scripts are executed in phases and must have `.sh` extension and be executable.

### Script Phases

| Phase | When | Use Cases |
|-------|------|-----------|
| `pre-init/` | Before system setup | Install packages, system config |
| `pre-user/` | Before user creation | SSH setup, fonts, system limits |
| `pre-vnc/` | Before VNC starts | User customization, shell config |
| `post-vnc/` | After VNC starts | VNC settings, display config |
| `post-init/` | After desktop loads | Auto-open apps, final setup |

### Basic Usage

See [Custom Scripts](CUSTOM_SCRIPTS.md).

## Troubleshooting

### Custom Scripts
**Script not executing:**
```bash
# Check script permissions and format
docker exec -it <container-name> find /entrypoint.d -name "*.sh" -exec ls -la {} \;

# View container logs for script output
docker logs <container-name>

# Check line endings (must be Unix LF, not Windows CRLF)
docker exec -it <container-name> file /entrypoint.d/pre-init/01-script.sh
```

**Common script issues:**
- Script not executable: `chmod +x script.sh`
- Wrong line endings: Use Unix LF format
- Missing shebang: Start with `#!/bin/bash`
- Permission errors: Use proper `chown` for user files

### VNC Connection Issues
- Verify the correct password is being used
- Check container logs: `docker logs <container-name>`
- Ensure port 5901 is properly exposed

### Namespace Permission Errors
If you see errors like "Failed to move to new namespace" or "Operation not permitted":

```bash
# Option 1: Run with privileged mode (most permissive)
docker run -d --privileged -p 5901:5901 lxqt-vnc

# Option 2: Add specific capabilities (recommended)
docker run -d --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE \
  -p 5901:5901 lxqt-vnc

# Option 3: Disable security profiles (if needed)
docker run -d --security-opt seccomp=unconfined \
  --security-opt apparmor=unconfined \
  -p 5901:5901 lxqt-vnc

# Option 4: For Docker Compose
services:
  lxqt-desktop:
    build: .
    ports:
      - "5901:5901"
    cap_add:
      - SYS_ADMIN
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
```

**Note**: These errors typically occur when browser-based applications try to create sandboxes. The above solutions provide the necessary permissions for proper desktop functionality.

### User Issues
- Custom users are created automatically with sudo privileges
- Check user creation in container logs
- Verify environment variables are set correctly

## Connect to Desktop

Use any VNC client to connect:
- **Host**: `localhost` (or your Docker host IP)
- **Port**: `5901`
- **Password**: Value of `VNC_PASSWORD` environment variable

The desktop will be ready immediately after connection.
