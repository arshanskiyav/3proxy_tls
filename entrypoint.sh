#!/bin/sh
set -e

CERT_MODE="${CERT_MODE:-dns}"
DOMAIN="${DOMAIN:-example.com}"
PROXY_PORT_HTTP=${PROXY_PORT_HTTP:-3128}
PROXY_PORT_HTTPS=${PROXY_PORT_HTTPS:-443}
PROXY_PORT_SOCKS=${PROXY_PORT_SOCKS:-1080}
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
WEBROOT="/var/www/letsencrypt"

if [ "$CERT_MODE" = "ip" ] && [ -n "$PROXY_EXT_IP" ]; then
  DOMAIN="$PROXY_EXT_IP"
  CERT_DIR="/etc/letsencrypt/ip/$DOMAIN"
fi
mkdir -p "$CERT_DIR"

if [ "$CERT_MODE" = "dns" ]; then
        # Prepare folder tree
        mkdir -p "$WEBROOT"
        cat > /etc/nginx/conf.d/letsencrypt.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location ^~ /.well-known/acme-challenge/ {
        root $WEBROOT;
        default_type "text/plain";
        try_files \$uri =404;
    }

    location / {
        return 204;
    }
}
EOF

  # CRON for letsencrypt FQDN
  echo "0 3 * * * certbot renew --webroot -w $WEBROOT --quiet --deploy-hook 'nginx -s reload && killall -HUP stunnel'" > /etc/cron.d/certbot_renew
  chmod 0644 /etc/cron.d/certbot_renew
  crontab /etc/cron.d/certbot_renew
  cron
fi

if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
        if [ "$CERT_MODE" = "ip" ]; then
                openssl req -x509 -nodes -days 365 \
                  -newkey rsa:2048 \
                  -keyout "$CERT_DIR/privkey.pem" \
                  -out "$CERT_DIR/fullchain.pem" \
                  -subj "/CN=$DOMAIN"
                cp "$CERT_DIR/fullchain.pem" "/etc/letsencrypt/proxy.crt"
        else
                nginx
                certbot certonly --non-interactive --agree-tos --register-unsafely-without-email \
                        --webroot -w "$WEBROOT" -d "$DOMAIN"
                nginx -s stop
        fi
fi


# Config 3proxy ENV
cat <<EOF > /etc/3proxy/3proxy.cfg
setgid ${gid:-65534}
setuid ${uid:-65534}
nserver 8.8.8.8
nserver 1.1.1.1
nscache 65536
external ${PROXY_EXT_IP:-0.0.0.0}
internal ${PROXY_INT_IP:-0.0.0.0}
timeouts 1 5 30 60 180 1800 15 60
users ${PROXY_USER_LIST:-user:CL:pass}
log
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
nscache 65536
auth cache strong
allow *
proxy -n -p$PROXY_PORT_HTTP -a
socks -n -p$PROXY_PORT_SOCKS -a
EOF

# TCP Wrappers stunnel
if [ -n "$STUNNEL_IP_LIST" ]; then
  if [ "$STUNNEL_ACCESS_MODE" = "allow" ]; then
    echo "proxy_tls: $STUNNEL_IP_LIST" >> /etc/hosts.deny
  else
    echo "proxy_tls: $STUNNEL_IP_LIST" >> /etc/hosts.allow
    echo "proxy_tls: ALL" >>/etc/hosts.deny
  fi
fi

# stunnel config
cat > /etc/stunnel/stunnel.conf <<EOF
foreground = yes
syslog = no
#Level is one of the syslog level names or numbers emerg (0), alert (1), crit (2), err (3), warning (4), notice (5), info (6), or debug (7)
debug=notice
[proxy_tls]
libwrap = yes
client = no
accept = $PROXY_PORT_HTTPS
#connect =  ${PROXY_EXT_IP:-127.0.0.1}:$PROXY_PORT_HTTP
connect = ${PROXY_EXT_IP:-127.0.0.1}:$PROXY_PORT_HTTP
cert = $CERT_DIR/fullchain.pem
key = $CERT_DIR/privkey.pem

EOF

echo
echo "=== ATTENTION ==="
echo
echo "You have to check your firewall rulles"
echo "For the HTTP/HTTPS proxy to work, you need to open port $PROXY_PORT_HTTP and $PROXY_PORT_HTTPS"
echo "For the SOCKS proxy to work, you need to open port $PROXY_PORT_SOCKS"
echo "For letsencrypt to work, you need to open port 80 (sometimes 443)"
echo
if [ "$CERT_MODE" = "ip" ]; then
        echo " ___________________________________________________________________________________"
        echo "|IP MODE                                                                            |"
        echo "|Copy file proxy.crt to client and install.                                         |"
        echo "|For linux based system                                                             |"
        echo "| sudo cp proxy.crt /usr/local/share/ca-certificates && sudo update-ca-certificates |"
        echo "|The path in container is /etc/letsencrypt.                                         |"
        echo "|If you use a named volume for this path you can find proxy.crt in the mount point  |"
        echo "|___________________________________________________________________________________|"
        echo
fi
echo "==============="
# RUN
stunnel &
3proxy /etc/3proxy/3proxy.cfg
wait
