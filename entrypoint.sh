#!/bin/sh
set -e

DOMAIN="${DOMAIN:-example.com}"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
WEBROOT="/var/www/letsencrypt"

# Prepare folder tree
mkdir -p "$WEBROOT"
mkdir -p "$CERT_DIR"
#mkdir -p /etc/3proxy

# Старт nginx для Let's Encrypt
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

nginx

# Check cert
if [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
    certbot certonly --non-interactive --agree-tos --register-unsafely-without-email \
      --webroot -w "$WEBROOT" -d "$DOMAIN"
fi

nginx -s stop

# Cron
echo "0 3 * * * certbot renew --webroot -w $WEBROOT --quiet --deploy-hook 'nginx -s reload && killall -HUP stunnel'" > /etc/cron.d/certbot_renew
chmod 0644 /etc/cron.d/certbot_renew
crontab /etc/cron.d/certbot_renew
cron

# Config 3proxy ENV
cat <<EOF > /etc/3proxy/3proxy.cfg
#setgid 65534
#setuid 65534
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
#proxy -n -p${PROXY_PORT_HTTP:-3128} -a
proxy -p${PROXY_PORT_HTTP:-3128}
EOF

# stunnel config
cat > /etc/stunnel/stunnel.conf <<EOF
[proxy_tls]
client = no
accept = ${PROXY_PORT_HTTPS:-443}
connect =  ${PROXY_EXT_IP:-127.0.0.1}:${PROXY_PORT_HTTP:-3128}
cert = $CERT_DIR/fullchain.pem
key = $CERT_DIR/privkey.pem
EOF

# RUN
stunnel &
3proxy /etc/3proxy/3proxy.cfg
wait
