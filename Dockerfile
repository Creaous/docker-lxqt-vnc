FROM archlinux:multilib-devel

# Setup keyring and install packages in a single layer
RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Syu --noconfirm \
    tigervnc \
    lxqt \
    lxqt-config \
    lximage-qt \
    lxqt-about \
    lxqt-archiver \
    lxqt-globalkeys \
    lxqt-notificationd \
    lxqt-openssh-askpass \
    lxqt-runner \
    lxqt-sudo \
    obconf-qt \
    qps \
    qterminal \
    screengrab \
    xdg-desktop-portal-lxqt \
    xorg-xdpyinfo \
    papirus-icon-theme \
    adwaita-icon-theme \
    hicolor-icon-theme \
    sudo \
    bash \
    base-devel \
    git \
    dbus && \
    pacman -Scc --noconfirm

# Create builder user, install paru, and cleanup in one layer
RUN useradd -m builder && \
    echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && \
    su - builder -c "git clone https://aur.archlinux.org/paru.git /tmp/paru && cd /tmp/paru && makepkg -si --noconfirm" && \
    userdel -r builder && \
    sed -i '/builder ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
    rm -rf /tmp/paru

# Create LXQt config directories and entrypoint script directories
RUN mkdir -p /root/.config/{lxqt,qt5ct,pcmanfm-qt/lxqt} && \
    mkdir -p /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    mkdir -p /var/log && \
    mkdir -p /entrypoint.d/{pre-init,pre-user,pre-vnc,post-vnc,post-init} && \
    chmod 755 /entrypoint.d && \
    chmod 755 /entrypoint.d/*

# Set environment variables for username and password
ENV VNC_USER=user
ENV VNC_PASSWORD=password
ENV SUDO_NOPASSWD=false

# Copy and setup entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose VNC port
EXPOSE 5901

ENTRYPOINT ["/entrypoint.sh"]
