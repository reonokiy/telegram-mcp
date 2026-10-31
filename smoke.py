"""Exercise the real HTTP transport without Telegram credentials or network access."""
import asyncio
import contextlib
import os
import secrets
import sys

os.environ.update(
    TELEGRAM_API_ID=str(secrets.randbelow(900000) + 100000),
    TELEGRAM_API_HASH=secrets.token_hex(16),
    TELEGRAM_SESSION_NAME=":memory:",
    MCP_ALLOWED_HOSTS="api.internal.nokiy.net",
)
sys.path.insert(0, "/app")

import httpx
from telegram_mcp.runner import _serve
from telegram_mcp.runtime import _apply_exposed_tools_mode, mcp


async def main():
    _apply_exposed_tools_mode()
    serving = asyncio.create_task(_serve("http"))
    try:
        async with httpx.AsyncClient(base_url="http://127.0.0.1:8765") as client:
            headers = {
                "Host": "api.internal.nokiy.net",
                "Accept": "application/json, text/event-stream",
            }
            for _ in range(100):
                if serving.done():
                    await serving
                try:
                    response = await client.get("/mcp", headers=headers)
                    if response.status_code == 200:
                        break
                except httpx.ConnectError:
                    pass
                await asyncio.sleep(0.05)
            else:
                raise AssertionError("HTTP transport did not start")

            initialize = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {},
                    "clientInfo": {"name": "container-check", "version": "1"},
                },
            }
            response = await client.post("/mcp", headers=headers, json=initialize)
            assert response.status_code == 200
            assert '"serverInfo"' in response.text
            listing = {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
            response = await client.post("/mcp", headers=headers, json=listing)
            assert response.status_code == 200
            for name in ("send_message", "reply_to_message", "delete_message", "get_messages"):
                assert f'"name":"{name}"' in response.text.replace(" ", "")
            wrong_host = {**headers, "Host": "untrusted.invalid"}
            response = await client.post("/mcp", headers=wrong_host, json=listing)
            assert 400 <= response.status_code < 500
            wrong_origin = {**headers, "Origin": "https://untrusted.invalid"}
            response = await client.post("/mcp", headers=wrong_origin, json=listing)
            assert 400 <= response.status_code < 500
        print("HTTP initialize/tools/list, write-tool registration, Host and Origin checks passed.")
    finally:
        serving.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await serving


asyncio.run(main())
