#!/usr/bin/env bash
set -euo pipefail

: "${SERVER_PORT:=6080}"

: "${PUBLIC_HOST:=}"

: "${PUBLIC_PROTO:=http}"

: "${NOVNC_PATH:=/vnc.html?autoconnect=true&resize=remote&path=websockify}"

: "${VNC_PASSWORD:=}"
: "${VNC_RESOLUTION:=1280x720}"
: "${VNC_DEPTH:=24}"
: "${VNC_DISPLAY:=:1}"
: "${VNC_INTERNAL_PORT:=5901}"

if [[ -z "${VNC_PASSWORD}" ]]; then
  echo "[ERR] VNC_PASSWORD is required" >&2
  exit 1
fi

export HOME=/home/container
mkdir -p "$HOME" "$HOME/.vnc"
cd "$HOME"

setup_nss_wrapper() {
  local uid gid
  uid="$(id -u)"
  gid="$(id -g)"

  if getent passwd "$uid" >/dev/null 2>&1; then
    return 0
  fi

  mkdir -p /tmp/ptero
  echo "container:x:${uid}:${gid}:Pterodactyl Runtime User:${HOME}:/bin/bash" > /tmp/ptero/passwd
  echo "container:x:${gid}:" > /tmp/ptero/group

  export NSS_WRAPPER_PASSWD=/tmp/ptero/passwd
  export NSS_WRAPPER_GROUP=/tmp/ptero/group

  local so=""
  for p in /usr/lib/*/libnss_wrapper.so /usr/lib/libnss_wrapper.so; do
    if [[ -e "$p" ]]; then
      so="$p"; break
    fi
  done
  if [[ -n "$so" ]]; then
    export LD_PRELOAD="$so${LD_PRELOAD:+:$LD_PRELOAD}"
  else
    echo "[WARN] libnss_wrapper.so not found; user lookups may fail." >&2
  fi
}
setup_nss_wrapper

printf '%s\n' "$VNC_PASSWORD" | vncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

cat > "$HOME/.vnc/xstartup" <<'XSTART'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export NO_AT_BRIDGE=1
xsetroot -solid grey
[ -r "$HOME/.Xresources" ] && xrdb "$HOME/.Xresources"
startxfce4 &
XSTART
chmod +x "$HOME/.vnc/xstartup"

rm -f /tmp/.X*-lock || true
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix || true

Xvnc "$VNC_DISPLAY" \
  -rfbauth "$HOME/.vnc/passwd" \
  -geometry "$VNC_RESOLUTION" \
  -depth "$VNC_DEPTH" \
  -SecurityTypes VncAuth \
  -rfbport "$VNC_INTERNAL_PORT" \
  -localhost \
  -AlwaysShared=1 \
  -DisconnectClients=0 \
  -pn \
  >/dev/stdout 2>/dev/stderr &

export DISPLAY="$VNC_DISPLAY"

( sleep 0.5; "$HOME/.vnc/xstartup" ) &

WEBROOT="/usr/share/novnc"
: "${WEBSOCKIFY_PORT:=6080}"

websockify --heartbeat=30 "127.0.0.1:${WEBSOCKIFY_PORT}" "127.0.0.1:${VNC_INTERNAL_PORT}" &
WS_PID=$!

mkdir -p /tmp/ptero/nginx/{client_body,proxy,fastcgi,uwsgi,scgi}

cat > /tmp/ptero/nginx.conf <<NGINXCONF
pid /tmp/ptero/nginx.pid;
error_log /dev/stderr notice;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /dev/stdout;
  sendfile on;

  client_body_temp_path /tmp/ptero/nginx/client_body;
  proxy_temp_path       /tmp/ptero/nginx/proxy;
  fastcgi_temp_path     /tmp/ptero/nginx/fastcgi;
  uwsgi_temp_path       /tmp/ptero/nginx/uwsgi;
  scgi_temp_path        /tmp/ptero/nginx/scgi;

  server {
    listen 0.0.0.0:${SERVER_PORT};
    server_name _;

    root ${WEBROOT};
    autoindex off;

    location = / {
      return 302 ${NOVNC_PATH};
    }

    location /websockify {
      proxy_pass http://127.0.0.1:${WEBSOCKIFY_PORT};
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_read_timeout 3600;
    }

    location / {
      try_files \$uri \$uri/ =404;
    }
  }
}
NGINXCONF

nginx -c /tmp/ptero/nginx.conf -g 'daemon off;' &
NGINX_PID=$!

for _ in $(seq 1 80); do
  (echo >/dev/tcp/127.0.0.1/${SERVER_PORT}) >/dev/null 2>&1 && break || true
  sleep 0.1
done

if [[ -n "${PUBLIC_HOST}" ]]; then
  PUBLIC_URL="${PUBLIC_PROTO}://${PUBLIC_HOST}:${SERVER_PORT}${NOVNC_PATH}"
else
  PUBLIC_URL="${PUBLIC_PROTO}://<NODE-IP>:${SERVER_PORT}${NOVNC_PATH}"
fi

echo ""
echo "WEBVNC READY"
echo "[OK] noVNC URL: ${PUBLIC_URL}"
if [[ -z "${PUBLIC_HOST}" ]]; then
  echo "[INFO] Set PUBLIC_HOST to your node IP/domain to print a real clickable URL."
fi
echo "[OK] Internal VNC: 127.0.0.1:${VNC_INTERNAL_PORT}  Display=${VNC_DISPLAY}  Resolution=${VNC_RESOLUTION}"
echo "[INFO] noVNC will ask for the VNC password you set in VNC_PASSWORD."
echo ""

wait ${NGINX_PID}
