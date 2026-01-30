"""Tests for the health MCP tool."""

import pytest

from config import get_settings
from mcp_tools.health import check_health


@pytest.mark.asyncio
async def test_health_mcp_tool_returns_status() -> None:
    settings = get_settings()
    payload = await check_health()

    assert payload["status"] == "healthy"
    assert payload["version"] == settings.app_version
    assert "timestamp" in payload
