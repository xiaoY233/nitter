# Deployment

Nitter needs two things at runtime: the `nitter` process and a Redis (or
Valkey) server for caching. It also needs at least one X account session, see
[sessions.md](sessions.md).

The Docker image is generic. It contains no configuration, no sessions and no
tokens; all of those are mounted or passed in when the container starts.

## Docker Compose (recommended)

`compose.yml` starts Nitter and Redis. It uses the image `vuldocker/nitter`.
Until that image is published, build it locally under the same name.

```sh
git clone https://github.com/xiaoY233/nitter.git && cd nitter

docker build -t vuldocker/nitter:latest .

cp nitter.example.conf nitter.conf
cp /path/to/sessions.jsonl .
chmod 644 nitter.conf sessions.jsonl     # the container runs as a non-root user
```

Edit `nitter.conf`:

```ini
[Server]
hostname = "your.domain.or.ip"

[Cache]
redisHost = "nitter-redis"               # the Redis service name in compose.yml

[Config]
hmacKey = "<output of: openssl rand -hex 32>"

[Api]
enabled = true
```

Create a token and hand it to the container through the environment:

```sh
echo "NITTER_API_TOKENS=me:$(openssl rand -hex 24)" > .env
```

In `compose.yml`, uncomment the `environment` block of the `nitter` service:

```yaml
    environment:
      NITTER_API_TOKENS: ${NITTER_API_TOKENS}
```

Start it and check the log:

```sh
docker compose up -d
docker compose logs nitter | head
```

A healthy start prints:

```
[sessions] successfully added 1 valid account sessions
Agent API enabled at /api/v1 and /mcp
Connected to Redis at nitter-redis:6379
```

`compose.yml` binds `127.0.0.1:8080`. Change it to `8080:8080` to reach the
server from other machines, and put a reverse proxy with HTTPS in front of it
when the traffic leaves a trusted network: the token travels in a request
header.

The Redis warning about `vm.overcommit_memory` comes from the host kernel
settings. It does not affect a cache-only Redis.

### Mounted files

The container reads `/src/nitter.conf` and `/src/sessions.jsonl`. If a mounted
file does not exist on the host, Docker creates a directory in its place and
the container fails with `not a directory`. Remove that directory and create
the file first.

### Plain `docker run`

```sh
docker network create nitter-net
docker run -d --name nitter-redis --network nitter-net \
  redis:6-alpine redis-server --save "" --loglevel warning
docker run -d --name nitter --network nitter-net -p 127.0.0.1:8080:8080 \
  -v "$PWD/nitter.conf:/src/nitter.conf:ro" \
  -v "$PWD/sessions.jsonl:/src/sessions.jsonl:ro" \
  -e NITTER_API_TOKENS="me:<secret>" \
  vuldocker/nitter:latest
```

## Build from source

Dependencies: Nim 2.x, `libpcre`, `libsass`, and Redis or Valkey.

```sh
git clone https://github.com/xiaoY233/nitter.git && cd nitter
nimble -l build -d:danger --mm:refc
nimble -l scss
nimble -l md
cp nitter.example.conf nitter.conf       # then edit it as above
./nitter
```

Sessions are read from `./sessions.jsonl`, or from the file named in the
environment variable `NITTER_SESSIONS_FILE`.

Run the unit tests of the agent API (no network, no Redis needed):

```sh
nimble install -y --depsOnly
nim c -r tests/test_agent_api.nim
```

### systemd

```ini
[Unit]
Description=Nitter
After=network.target

[Service]
Type=simple
User=nitter
Group=nitter
WorkingDirectory=/home/nitter/nitter
Environment=NITTER_API_TOKENS=me:<secret>
ExecStart=/home/nitter/nitter/nitter
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
```

```sh
systemctl enable --now nitter.service
journalctl -u nitter.service --follow
```

## Smoke test

Replace `<secret>` with the part of the token after the colon.

```sh
B=http://127.0.0.1:8080; A="Authorization: Bearer <secret>"

curl -s $B/api/v1/health                                     # {"status":"ok",...}
curl -s -o /dev/null -w "%{http_code}\n" $B/api/v1/tools     # 401 without a token
curl -s -H "$A" "$B/api/v1/users/jack?format=markdown"       # live data
curl -s -H "$A" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' $B/mcp | head -c 300
```

## Logging

Nitter prints errors to stdout and has no log files. Use `docker logs --follow
nitter` or `journalctl -u nitter.service`. Setting `enableDebug = true` adds
request logs and the `/.sessions` endpoint, which exposes session details; use
it for troubleshooting only.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Starts, then exits with a message about API enabled but no token | `NITTER_API_TOKENS` did not reach the container. Check the `environment` block and `.env`. |
| Every data call returns `rate_limited` and `/.health` shows `"requests": {"total": 0}` | The container cannot reach X (DNS, firewall, proxy). Nitter reports network failures as rate limits. Set `proxy` in `[Config]` if you need one. |
| `rate_limited` and `/.health` shows `limited` sessions | X is rate limiting the session. See [sessions.md](sessions.md). |
| `not_found` for accounts that exist | The session is invalid or locked. Look for `invalidating` in the log. |
| `404` from `/mcp` or `/api/v1` | `[Api] enabled` is `false`, or the container runs the upstream image instead of this one. |
