#!/usr/bin/env bash
set -Eeuo pipefail

############################
# ENV
############################
: "${SERVER_PORT:=6080}"
: "${WEBSOCKIFY_PORT:=6080}"
: "${VNC_PASSWORD:?VNC_PASSWORD is required}"

: "${VNC_DISPLAY:=:1}"
: "${VNC_INTERNAL_PORT:=5901}"
: "${VNC_RESOLUTION:=1280x720}"
: "${VNC_DEPTH:=24}"

: "${PUBLIC_HOST:=}"
: "${PUBLIC_PROTO:=http}"
: "${NOVNC_PATH:=/vnc.html?autoconnect=true&resize=remote&path=websockify}"


export HOME=/tmp/home
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_RUNTIME_DIR="$HOME/.runtime"

VNC_DIR="/tmp/vnc"
NGINX_DIR="/tmp/nginx"
WEBROOT="/usr/share/novnc"

mkdir -p \
  "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR" \
  "$VNC_DIR" \
  "$NGINX_DIR"/{client_body,proxy,fastcgi,uwsgi,scgi} \
  /tmp/.X11-unix

chmod 700 "$HOME" "$VNC_DIR"
chmod 1777 /tmp/.X11-unix || true


if ! getent passwd "$(id -u)" >/dev/null; then
  mkdir -p /tmp/nss
  echo "container:x:$(id -u):$(id -g):Container:$HOME:/bin/bash" > /tmp/nss/passwd
  echo "container:x:$(id -g):" > /tmp/nss/group
  export NSS_WRAPPER_PASSWD=/tmp/nss/passwd
  export NSS_WRAPPER_GROUP=/tmp/nss/group

  for so in /usr/lib/*/libnss_wrapper.so /usr/lib/libnss_wrapper.so; do
    [[ -e "$so" ]] && export LD_PRELOAD="$so" && break
  done
fi

printf '%s\n' "$VNC_PASSWORD" | vncpasswd -f > "$VNC_DIR/passwd"
chmod 600 "$VNC_DIR/passwd"
cat > "$VNC_DIR/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export NO_AT_BRIDGE=1

# Start dbus (REQUIRED)
if command -v dbus-launch >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
fi

xsetroot -solid grey
exec startxfce4 &
EOF
chmod +x "$VNC_DIR/xstartup"

rm -f /tmp/.X*-lock || true

Xvnc "$VNC_DISPLAY" \
  -rfbauth "$VNC_DIR/passwd" \
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

for i in $(seq 1 50); do
  xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && break
  sleep 0.1
done

"$VNC_DIR/xstartup" &

############################
# WEBSOCKIFY
############################
websockify --heartbeat=30 \
  "127.0.0.1:${WEBSOCKIFY_PORT}" \
  "127.0.0.1:${VNC_INTERNAL_PORT}" &
WS_PID=$!

############################
# NGINX (noVNC)
############################
cat > /tmp/nginx.conf <<EOF
pid /tmp/nginx.pid;
error_log /dev/stderr notice;

events { worker_connections 1024; }

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /dev/stdout;

  client_body_temp_path $NGINX_DIR/client_body;
  proxy_temp_path       $NGINX_DIR/proxy;
  fastcgi_temp_path     $NGINX_DIR/fastcgi;
  uwsgi_temp_path       $NGINX_DIR/uwsgi;
  scgi_temp_path        $NGINX_DIR/scgi;

  server {
    listen 0.0.0.0:${SERVER_PORT};
    root ${WEBROOT};

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
EOF

nginx -c /tmp/nginx.conf -g 'daemon off;' &
NGINX_PID=$!

if [[ -n "$PUBLIC_HOST" ]]; then
  URL="${PUBLIC_PROTO}://${PUBLIC_HOST}:${SERVER_PORT}${NOVNC_PATH}"
else
  URL="${PUBLIC_PROTO}://<NODE-IP>:${SERVER_PORT}${NOVNC_PATH}"
fi

echo ""
echo "=============================="
echo "  WEB VNC READY "
echo "------------------------------"
echo "[OK] URL        : $URL"
echo "[OK] DISPLAY    : $VNC_DISPLAY"
echo "[OK] RESOLUTION : $VNC_RESOLUTION"
echo "[OK] USER HOME  : $HOME"
echo "=============================="
echo ""

wait "$NGINX_PID"
