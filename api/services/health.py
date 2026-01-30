"""Health check service implementation."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from config import Settings, get_settings
from schemas.health import HealthStatus


class HealthService:
    """Health check service shared by REST and MCP."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    async def check_health(self) -> HealthStatus:
        """Check the health of the API and its dependencies."""

        return HealthStatus(
            status="healthy",
            version=self._settings.app_version,
            timestamp=datetime.now(timezone.utc),
        )


def get_health_service(settings: Optional[Settings] = None) -> HealthService:
    """Create a health service instance."""

    if settings is None:
        settings = get_settings()
    return HealthService(settings)
