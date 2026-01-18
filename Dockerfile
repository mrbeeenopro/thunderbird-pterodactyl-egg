FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    nginx-light \
    openbox \
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
  mkdir -p /var/lib/openbox; \
  (update-menus || true); \
  if [ ! -s /var/lib/openbox/debian-menu.xml ]; then \
    printf '%s\n' \
      '<openbox_menu xmlns="http://openbox.org/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' \
      ' xsi:schemaLocation="http://openbox.org/ file:///usr/share/openbox/menu.xsd">' \
      '  <menu id="root-menu" label="Applications">' \
      '    <item label="Terminal"><action name="Execute"><command>xterm</command></action></item>' \
      '    <item label="Thunderbird"><action name="Execute"><command>thunderbird --no-remote</command></action></item>' \
      '  </menu>' \
      '</openbox_menu>' \
      > /var/lib/openbox/debian-menu.xml; \
  fi; \
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
