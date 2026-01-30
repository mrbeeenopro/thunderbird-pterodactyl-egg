FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

RUN set -eux; \
  apt-get update; \
  apt-get install -y \
    ca-certificates \
    bash \
    sudo \
    dbus-x11 \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-panel \
    xfce4-session \
    xfce4-settings \
    xfconf \
    xfdesktop4 \
    xfwm4 \
    thunar \
    file-roller \
    xterm \
    xauth \
    x11-xserver-utils \
    tigervnc-standalone-server \
    tigervnc-tools \
    novnc \
    websockify \
    nginx-light \
    fonts-dejavu \
    menu menu-xdg \
    lxappearance \
    xclip \
    neofetch \
    htop btop \
    curl wget git \
    net-tools iputils-ping \
    build-essential \
    python3 python3-pip \
    nodejs npm \
    unzip zip p7zip-full \
    evince okular \
    galculator \
    simple-scan \
    gimp mpv \
    sqlitebrowser \
    firefox-esr chromium \
    vlc \
    libpci3 \
    libegl1 \
    libgl1 \
    libgl1-mesa-dri \
    libnss-wrapper \
    python3-xdg \
    xdg-utils; \
  rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  apt-get update; \
  apt-get install -y \
    remmina \
    remmina-plugin-rdp \
    remmina-plugin-vnc \
    freerdp2-x11 \
    rdesktop \
    openssh-client; \
  rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  apt-get update; \
  apt-get install -y \
    libreoffice \
    libreoffice-gtk3 \
    libreoffice-l10n-vi; \
  rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  apt-get update; \
  apt-get install -y wget gpg; \
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/ms.gpg; \
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms.gpg] https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list; \
  apt-get update; \
  apt-get install -y code; \
  rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  apt-get update; \
  apt-get install -y openjdk-17-jdk; \
  mkdir -p /opt; \
  wget -O /tmp/as.tar.gz https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2024.1.1.11/android-studio-2024.1.1.11-linux.tar.gz; \
  tar -xzf /tmp/as.tar.gz -C /opt; \
  ln -s /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio; \
  rm /tmp/as.tar.gz

RUN set -eux; \
  apt-get update; \
  apt-get install -y git; \
  mkdir -p /usr/share/themes /usr/share/icons; \
  git clone https://github.com/h3l2f/lememStuff /tmp/lemem; \
  cp -r /tmp/lemem/themes/* /usr/share/themes/ || true; \
  cp -r /tmp/lemem/icons/* /usr/share/icons/ || true; \
  rm -rf /tmp/lemem /var/lib/apt/lists/*

RUN mkdir -p /home/container \
    /tmp/ptero \
    /tmp/.X11-unix \
 && chmod 0777 /home/container /tmp/ptero \
 && chmod 1777 /tmp/.X11-unix

WORKDIR /home/container

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/bin/bash", "/entrypoint.sh"]
