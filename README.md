# 3proxy TLS in Docker

It is a ready-made docker container 3proxy encasulated in TLS using stunnel. You can use it if you need to quickly set up an HTTPS proxy with auth. There is support for letsencrypt or self-signed certificates

---

## 📦 Possibilities
- Classic HTTP-proxy (or SOCKS if you change config in entrypoint.sh)
- HTTPS-proxy via stunnel
- Generate certificate for your domain (`CERT_MODE=dns`) or self-signed (`CERT_MODE=ip`)
- Configure auth via ENV
- IP Access Control via TCP Wrappers (TLS only)
- Put stunnel and 3proxy logs to stdout

---

## 🚀 Quick start

### 1. Clone the repository
```bash
git clone https://github.com/arshanskiyav/3proxy_tls.git
cd 3proxy_tls
```

### 2. Set up your `.env`
Example:
```env
CERT_MODE=dns
DOMAIN=proxy.example.com
PROXY_EXT_IP=225.222.111.123
PROXY_INT_IP=225.222.111.123
PROXY_PORT_HTTP=3128
PROXY_PORT_HTTPS=443
PROXY_PORT_SOCKS=1080
PROXY_USER_LIST=user1:CL:pass1 user2:CL:pass2
STUNNEL_POLICY_DENY=false
STUNNEL_IP_LIST=1.2.3.4 5.6.7.8
```

### 3. Run docker container used `docker-compose`
```bash
docker compose up -d
```

---

## 🛠 Environment variables `.env`

| Variable             | Description                                                                 | Default<br>value | Required |
|------------------------|---------------------------------------------------------------------------|------------------------|--------------|
| `CERT_MODE`            | `dns` (Let's Encrypt) or `ip` (self-signed)                              | dns                    | yes           |
| `DOMAIN`               | FQDN for Let's Encrypt                                                    | —                      | yes (if CERT_MODE=dns) |
| `PROXY_EXT_IP`         | IP used for incoming connections and when creating self-signed certificates | 0.0.0.0                | yes           |
| `PROXY_INT_IP`         | IP used for output connections                                            | 0.0.0.0              | no          |
| `PROXY_PORT_HTTP`      | 3proxy port | 3128                   | no          |
| `PROXY_PORT_HTTPS`     | Stunnel port                                          | 443                    | no          |
| `PROXY_PORT_SOCKS`     | SOCKS port                                          | 1080                    | no          |
| `PROXY_USER_LIST`      | List of users in 3proxy format (see examples) : `user:CL:pass` space separated       | user:CL:pass           | yes           |
| `STUNNEL_ACCESS_MODE`  | `deny` — deny-politics (only ip from STUNNEL_IP_LIST has access), <br>`allow` — allow-politic (STUNNEL_IP_LIST contains blocked IP addresses)                         | allow                  | no          |
| `STUNNEL_IP_LIST`      | A list of IP addresses or subnets separated by spaces.                                       | —                      | no (except in cases where STUNNEL_ACCESS_MODE is defined) |


---

## 🔐 Specifics
- TCP Wrappers (`hosts.allow` / `hosts.deny`) works **with only TLS-connections**. If you use an HTTP-proxy the rules will be ignored.
- If you use `CERT_MODE=ip` you need to add the generated certificate to the trusted list on the client.
- The container runs in `network_mode: host`, which means you need to manually add firewall rules

---

## 📂 Structure
- `Dockerfile`
- `entrypoint.sh` — generates configs and runs services
- `docker-compose.yml`

---

## 📜 Licence
MIT
