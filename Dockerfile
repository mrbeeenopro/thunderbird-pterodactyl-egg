FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    nginx-light \
    xfce4-goodies \
    xfce4 \
    libxfce4ui-utils \
    thunar \
    xfce4-appfinder \
    xfce4-panel \
    xfce4-session \
    xfce4-settings \
    xfce4-terminal \
    xfconf \
    xfdesktop4 \
    xfwm4
    xterm \
    xauth \
    x11-xserver-utils \
    tigervnc-standalone-server \
    tigervnc-tools \
    novnc \
    websockify \
    thunderbird \
    fonts-dejavu \
    libnss-wrapper \
    python3-xdg \
    xdg-utils \
    menu \
    menu-xdg \
    libpci3 \
    libegl1 \
    libgl1 \
    libgl1-mesa-dri; \
  rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/container \
 && chmod 0777 /home/container \
 && mkdir -p /tmp/ptero \
 && chmod 0777 /tmp/ptero \
 && mkdir -p /tmp/.X11-unix \
 && chmod 1777 /tmp/.X11-unix \
 && chown root:root /tmp/.X11-unix

WORKDIR /home/container

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["bash","/start.sh"]
