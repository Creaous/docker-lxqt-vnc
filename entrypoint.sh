#!/bin/bash

# Get environment variables with defaults
VNC_USER=${VNC_USER:-root}
VNC_PASSWORD=${VNC_PASSWORD:-password}
SUDO_NOPASSWD=${SUDO_NOPASSWD:-false}

echo "Starting Docker LXQT VNC container..."
echo "VNC User: $VNC_USER"
echo "Sudo requires password: $([ "$SUDO_NOPASSWD" = "true" ] && echo "No" || echo "Yes")"

# Function to execute user-provided scripts in a specific phase
execute_entrypoint_scripts() {
    local phase=$1
    local script_dir="/entrypoint.d/$phase"

    if [ -d "$script_dir" ] && [ "$(ls -A "$script_dir" 2>/dev/null)" ]; then
        echo "Executing $phase scripts..."
        for script in "$script_dir"/*.sh; do
            if [ -f "$script" ] && [ -x "$script" ]; then
                echo "  Running: $(basename "$script")"
                if ! "$script"; then
                    echo "  WARNING: Script $(basename "$script") failed with exit code $?"
                    echo "  Continuing with startup process..."
                fi
            elif [ -f "$script" ]; then
                echo "  WARNING: Script $(basename "$script") is not executable, skipping"
            fi
        done
        echo "Completed $phase scripts"
    fi
}

# Execute pre-init scripts (before any system setup)
execute_entrypoint_scripts "pre-init"

# Function to create user if it doesn't exist
create_user() {
    local username=$1
    if ! id "$username" &>/dev/null; then
        echo "Creating user: $username"
        useradd -m -s /bin/bash "$username"
        echo "$username:$VNC_PASSWORD" | chpasswd
        # Add user to sudo group
        usermod -aG wheel "$username"

        # Configure sudo based on SUDO_NOPASSWD setting
        if [ "$SUDO_NOPASSWD" = "true" ]; then
            echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
            echo "✓ User $username configured with passwordless sudo"
        else
            echo "$username ALL=(ALL) ALL" >> /etc/sudoers
            echo "✓ User $username configured with password-required sudo"
        fi
    else
        echo "User $username already exists"
        # Update password if user exists
        echo "$username:$VNC_PASSWORD" | chpasswd
    fi
}

# Function to setup user directories and configs
setup_user_config() {
    local username=$1
    local user_home

    if [ "$username" = "root" ]; then
        user_home="/root"
    else
        user_home="/home/$username"
    fi

    echo "Setting up configuration for user: $username in $user_home"

    # Create LXQt config directories
    mkdir -p "$user_home/.config/"{lxqt,qt5ct,pcmanfm-qt/lxqt}

    # Create VNC directory and set password
    mkdir -p "$user_home/.vnc"

    # Set VNC password
    echo "$VNC_PASSWORD" | vncpasswd -f > "$user_home/.vnc/passwd"
    chmod 600 "$user_home/.vnc/passwd"

    # Create LXQT session configuration with Papirus icon theme
    cat > "$user_home/.config/lxqt/session.conf" << 'EOF'
[General]
icon_theme=Papirus
theme=system

[Environment]
QT_QPA_PLATFORMTHEME=lxqt
EOF

    # Create LXQT desktop configuration
    cat > "$user_home/.config/lxqt/desktop.conf" << 'EOF'
[General]
iconTheme=Papirus
EOF

    # Create LXQT theme configuration
    cat > "$user_home/.config/lxqt/lxqt.conf" << 'EOF'
[General]
icon_theme=Papirus
theme=system

[Qt]
style=Fusion
EOF

    # Create Qt5 configuration for fallback
    cat > "$user_home/.config/qt5ct/qt5ct.conf" << 'EOF'
[Appearance]
icon_theme=Papirus
style=Fusion

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x12\0M\0o\0n\0o\0s\0p\0\x61\0\x63\0\x65@\"\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x12\0N\0o\0t\0o\0 \0S\0\x61\0n\0s@\"\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
EOF



    # Create PCManFM-Qt configuration for proper icon display
    cat > "$user_home/.config/pcmanfm-qt/lxqt/settings.conf" << 'EOF'
[Behavior]
BookmarkOpenMethod=current_tab
ConfirmDelete=true
ConfirmTrash=false
NoUsbTrash=false
QuickExec=false
SelectNewFiles=false
SingleClick=false
UseTrash=true

[Desktop]
AllSticky=false
DesktopCellMargins=@Size(3 1)
DesktopIconSize=48
DesktopShortcuts=@Invalid()
Font="Sans Serif,9,-1,5,50,0,0,0,0,0"
HideItems=false
LastSlide=-1
OpenWithDefaultFileManager=false
PerScreenWallpaper=false
ShowHidden=false
SlideShowInterval=0
SortColumn=name
SortFolderFirst=true
SortHiddenLast=false
SortOrder=ascending

[FolderView]
BackupAsHidden=false
BigIconSize=48
FolderViewCellMargins=@Size(3 3)
HiddenLast=false
Mode=icon
ShadowHidden=false
ShowFilter=false
ShowFullNames=false
ShowHidden=false
SidePaneIconSize=24
SmallIconSize=24
SortCaseSensitive=false
SortColumn=name
SortFolderFirst=true
SortOrder=ascending
ThumbnailIconSize=128

[Places]
HiddenPlaces=

[System]
Archiver=
FallbackIconThemeName=hicolor
IconTheme=Papirus
SIUnit=false
SuCommand=sudo
Terminal=qterminal
EOF

    # Create LXQT panel configuration for proper icon display
    cat > "$user_home/.config/lxqt/panel.conf" << 'EOF'
[General]
iconTheme=Papirus

[desktopswitch]
alignment=Left
type=desktopswitch

[mainmenu]
alignment=Left
icon=/usr/share/icons/Papirus/22x22/places/distributor-logo-archlinux.svg
type=mainmenu

[quicklaunch]
alignment=Left
type=quicklaunch

[taskbar]
alignment=Left
type=taskbar

[tray]
alignment=Right
type=tray

[clock]
alignment=Right
type=clock
EOF

    # Set ownership of config files
    if [ "$username" != "root" ]; then
        chown -R "$username:$username" "$user_home/.config" "$user_home/.vnc"
    fi
}

# Function to start VNC server as user
start_vnc_server() {
    local username=$1
    local user_home

    if [ "$username" = "root" ]; then
        user_home="/root"
    else
        user_home="/home/$username"
    fi

    echo "Starting VNC server for user: $username"

    # Set display and other environment variables
    export DISPLAY=:1
    export QT_QPA_PLATFORMTHEME=lxqt
    export QT_STYLE_OVERRIDE=Fusion

    # Refresh icon cache to ensure proper loading
    echo "Refreshing icon cache..."
    gtk-update-icon-cache /usr/share/icons/Papirus 2>/dev/null || true
    gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true

    # Debug: Print icon theme configuration
    echo "Icon theme configuration:"
    echo "QT_QPA_PLATFORMTHEME=$QT_QPA_PLATFORMTHEME"
    echo "Available icon themes:"
    ls -la /usr/share/icons/ | grep -E "(Papirus|hicolor|Adwaita)"

    # Create startup script for the user session
    local startup_script="/tmp/start_desktop_${username}.sh"
    echo "Creating startup script: $startup_script"

    cat > "$startup_script" << EOF
#!/bin/bash
export DISPLAY=:1
export QT_QPA_PLATFORMTHEME=lxqt
export QT_STYLE_OVERRIDE=Fusion

echo "Starting Xvnc server for $username..."
Xvnc :1 -geometry 1024x768 -depth 24 -rfbauth $user_home/.vnc/passwd -localhost=0 -SecurityTypes VncAuth -AlwaysShared &
VNC_PID=\$!
echo "VNC server started with PID: \$VNC_PID"

# Wait for X server to be ready
echo "Waiting for X server to start..."
for i in {1..15}; do
    if xdpyinfo -display :1 >/dev/null 2>&1; then
        echo "✓ X server is ready"
        break
    fi
    sleep 1
done

# Execute post-vnc scripts (after VNC server starts, before desktop environment)
if [ -d "/entrypoint.d/post-vnc" ] && [ "\$(ls -A "/entrypoint.d/post-vnc" 2>/dev/null)" ]; then
    echo "Executing post-vnc scripts..."
    for script in /entrypoint.d/post-vnc/*.sh; do
        if [ -f "\$script" ] && [ -x "\$script" ]; then
            echo "  Running: \$(basename "\$script")"
            if ! "\$script"; then
                echo "  WARNING: Script \$(basename "\$script") failed with exit code \$?"
                echo "  Continuing with startup process..."
            fi
        elif [ -f "\$script" ]; then
            echo "  WARNING: Script \$(basename "\$script") is not executable, skipping"
        fi
    done
    echo "Completed post-vnc scripts"
fi

# Start user session dbus
if [ -z "\$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval \$(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
    echo "✓ User session dbus started"
fi



# Start LXQt desktop environment
echo "Starting LXQt desktop environment..."
startlxqt &
LXQT_PID=\$!

# Execute post-init scripts (after desktop environment starts)
if [ -d "/entrypoint.d/post-init" ] && [ "\$(ls -A "/entrypoint.d/post-init" 2>/dev/null)" ]; then
    echo "Executing post-init scripts..."
    for script in /entrypoint.d/post-init/*.sh; do
        if [ -f "\$script" ] && [ -x "\$script" ]; then
            echo "  Running: \$(basename "\$script")"
            if ! "\$script"; then
                echo "  WARNING: Script \$(basename "\$script") failed with exit code \$?"
                echo "  Continuing with startup process..."
            fi
        elif [ -f "\$script" ]; then
            echo "  WARNING: Script \$(basename "\$script") is not executable, skipping"
        fi
    done
    echo "Completed post-init scripts"
fi

echo "Container ready! Connect to VNC on port 5901"
echo "VNC Password: hidden (this is the same as the user password!)"

# Keep container running
while true; do
    if ! kill -0 \$VNC_PID 2>/dev/null; then
        echo "VNC server died, exiting..."
        exit 1
    fi
    if ! kill -0 \$LXQT_PID 2>/dev/null; then
        echo "LXQt died, restarting..."
        startlxqt &
        LXQT_PID=\$!
    fi
    sleep 10
done
EOF

    # Verify script was created
    if [ ! -f "$startup_script" ]; then
        echo "ERROR: Failed to create startup script"
        exit 1
    fi

    chmod +x "$startup_script"
    echo "Startup script created and made executable"

    if [ "$username" = "root" ]; then
        # Run as root
        echo "Executing startup script as root..."
        exec "$startup_script"
    else
        # Run as user and don't return
        chown "$username:$username" "$startup_script"
        echo "Executing startup script as user: $username"
        exec su - "$username" -c "$startup_script"
    fi
}

# Main execution flow
echo "Setting up user and VNC environment..."

# Execute pre-user scripts (before user creation and setup)
execute_entrypoint_scripts "pre-user"

# Start dbus service
echo "Starting dbus service..."
mkdir -p /run/dbus
if ! pidof dbus-daemon > /dev/null; then
    dbus-daemon --system --fork
    echo "✓ System dbus started"
else
    echo "✓ System dbus already running"
fi

# Create user if not root
if [ "$VNC_USER" != "root" ]; then
    create_user "$VNC_USER"
fi

# Setup configuration for the user
setup_user_config "$VNC_USER"

# Execute pre-vnc scripts (after user setup, before VNC server starts)
execute_entrypoint_scripts "pre-vnc"

# Ensure user home directory exists and has correct permissions
if [ "$VNC_USER" != "root" ]; then
    if [ ! -d "/home/$VNC_USER" ]; then
        echo "[PRE-VNC] Creating home directory for user: $VNC_USER"
        mkdir -p "/home/$VNC_USER"
        chown "$VNC_USER:$VNC_USER" "/home/$VNC_USER"
    fi

    # Ensure user owns their home directory
    chown -R "$VNC_USER:$VNC_USER" "/home/$VNC_USER"
fi

# Start VNC server and desktop environment
start_vnc_server "$VNC_USER"
