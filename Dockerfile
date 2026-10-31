FROM ghcr.io/astral-sh/uv:0.13.5@sha256:32a7bb39b496babbd997b0a39a4d66c126bdaf5661b302bf6f06abda8deca6ff AS uv
FROM docker.io/library/python:3.13-slim-bookworm@sha256:281d39ff02e3b389401586134ff9e6572954687822a58055ec07a60ded4e0b7f AS builder
COPY --from=uv /uv /usr/local/bin/uv
ADD https://codeload.github.com/chigwell/telegram-mcp/tar.gz/0246df8c3c99818d68f50e8591b2d3dda8363f81 /tmp/source.tar.gz
RUN echo "1d0a17bb51e1b9456e4afc70ccc662dc8277fe32cd07d450021a288978548a6f  /tmp/source.tar.gz" | sha256sum -c - && \
    mkdir /app && tar -xzf /tmp/source.tar.gz --strip-components=1 -C /app
WORKDIR /app
ENV UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never
RUN uv sync --frozen --no-dev --no-install-project

FROM docker.io/library/python:3.13-slim-bookworm@sha256:281d39ff02e3b389401586134ff9e6572954687822a58055ec07a60ded4e0b7f
LABEL org.opencontainers.image.source="https://github.com/reonokiy/telegram-mcp" \
      org.opencontainers.image.version="2.0.1" \
      org.opencontainers.image.description="chigwell/telegram-mcp at 0246df8c3c99818d68f50e8591b2d3dda8363f81"
COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/main.py /app/sanitize.py /app/LICENSE /app/
COPY --from=builder /app/telegram_mcp /app/telegram_mcp
COPY smoke.py /opt/smoke.py
RUN groupadd --gid 10001 mcp && useradd --uid 10001 --gid 10001 --home-dir /data --no-create-home mcp && \
    mkdir -p /data /tmp && chown 10001:10001 /data && \
    ln -s /dev/stderr /app/mcp_errors.log && chmod -R a+rX /app
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/data \
    XDG_STATE_HOME=/data/state \
    MCP_TRANSPORT=http \
    MCP_HOST=0.0.0.0 \
    MCP_PORT=8765 \
    TELEGRAM_EXPOSED_TOOLS=all \
    TELEGRAM_ALLOWED_ROOTS=/data \
    TELEGRAM_SERVER_ROOTS_ONLY=true \
    TELEGRAM_TRANSCRIBE_ENGINE=telegram
WORKDIR /data
USER 10001:10001
EXPOSE 8765
ENTRYPOINT ["python", "/app/main.py"]
