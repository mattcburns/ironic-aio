"""Tests for the health MCP tool."""

import pytest

from config import get_settings
from mcp_tools import health as health_tool
from services.health import HealthService


class FakeIronicClient:
    """Test double for the Ironic client."""

    def __init__(self, connected: bool) -> None:
        self._connected = connected

    async def check_connectivity(self) -> bool:
        return self._connected


@pytest.mark.asyncio
async def test_health_mcp_tool_returns_status() -> None:
    settings = get_settings()
    original_get_health_service = health_tool.get_health_service
    health_tool.get_health_service = lambda: HealthService(
        settings=settings,
        ironic_client=FakeIronicClient(connected=True),
    )

    payload = await health_tool.check_health()

    health_tool.get_health_service = original_get_health_service

    assert payload["status"] == "healthy"
    assert payload["version"] == settings.app_version
    assert "timestamp" in payload
    assert payload["ironic_connected"] is True
    assert payload["ironic_api_version"] == settings.ironic_api_version
