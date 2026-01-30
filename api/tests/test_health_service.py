"""Tests for the health service."""

import pytest

from config import get_settings
from services.health import get_health_service


@pytest.mark.asyncio
async def test_health_service_returns_status() -> None:
    settings = get_settings()
    service = get_health_service()
    result = await service.check_health()

    assert result.status == "healthy"
    assert result.version == settings.app_version
    assert result.timestamp.tzinfo is not None
