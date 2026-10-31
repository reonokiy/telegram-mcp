# Telegram MCP container

Container packaging of [chigwell/telegram-mcp](https://github.com/chigwell/telegram-mcp),
fixed at commit `0246df8c3c99818d68f50e8591b2d3dda8363f81` (2.0.1).
This repository contains only build and verification files. Upstream source is
downloaded by full commit and verified by SHA-256; dependencies use its frozen
`uv.lock`. The unrelated PyPI package named `telegram-mcp` is never installed.

GitHub Actions tests the actual Streamable HTTP transport without a Telegram
connection, then publishes `ghcr.io/reonokiy/telegram-mcp:sha-<build-commit>`.
Production deployments should use the digest recorded in the workflow summary.
The GHCR package must be public for anonymous Kubernetes pulls.

The image runs as UID/GID 10001 with a read-only root filesystem. Mount writable
temporary directories at `/tmp` and `/data`. `/data` contains transient downloads,
aliases and transcription caches; it is not a credential store. All registered
tools, including write tools, are enabled. File tools are confined to `/data`.
Transcription uses Telegram, without uploading audio to a third-party AI provider;
availability depends on the Telegram account.

Provide `TELEGRAM_API_ID`, `TELEGRAM_API_HASH`, and `TELEGRAM_SESSION_STRING` through
your secret manager at runtime. A human must generate the session using the pinned
upstream source on a trusted machine. Never commit credentials or session files,
submit them to CI, or include them in issue reports.

HTTP listens on `0.0.0.0:8765`, endpoint `/mcp`. Set `MCP_ALLOWED_HOSTS` to the exact
reverse-proxy hostname. Put the service behind an authenticated private ingress;
the image does not provide user authentication.

Local verification:

```sh
docker build -t telegram-mcp:check .
docker run --rm --network none --read-only --cap-drop ALL \
  --security-opt no-new-privileges \
  --tmpfs /tmp:rw,nosuid,nodev,size=64m,uid=10001,gid=10001 \
  --tmpfs /data:rw,nosuid,nodev,size=64m,uid=10001,gid=10001 \
  --entrypoint python telegram-mcp:check /opt/smoke.py
```
