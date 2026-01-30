"""Tests for the health service."""

import pytest

from config import get_settings
from services.health import HealthService


class FakeIronicClient:
    """Test double for the Ironic client."""

    def __init__(self, connected: bool) -> None:
        self._connected = connected

    async def check_connectivity(self) -> bool:
        return self._connected


@pytest.mark.asyncio
async def test_health_service_returns_status() -> None:
    settings = get_settings()
    service = HealthService(
        settings=settings,
        ironic_client=FakeIronicClient(connected=True),
    )
    result = await service.check_health()

    assert result.status == "healthy"
    assert result.version == settings.app_version
    assert result.timestamp.tzinfo is not None
    assert result.ironic_connected is True
    assert result.ironic_api_version == settings.ironic_api_version


@pytest.mark.asyncio
async def test_health_service_degraded_when_ironic_down() -> None:
    settings = get_settings()
    service = HealthService(
        settings=settings,
        ironic_client=FakeIronicClient(connected=False),
    )
    result = await service.check_health()

    assert result.status == "degraded"
    assert result.ironic_connected is False
    assert result.ironic_api_version is None
