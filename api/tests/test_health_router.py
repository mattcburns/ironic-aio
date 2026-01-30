"""Tests for the health router."""

from fastapi.testclient import TestClient

from app import app
from config import get_settings
from services.health import HealthService, get_health_service


class FakeIronicClient:
    """Test double for the Ironic client."""

    def __init__(self, connected: bool) -> None:
        self._connected = connected

    async def check_connectivity(self) -> bool:
        return self._connected


def test_health_endpoint_returns_status(client: TestClient) -> None:
    settings = get_settings()
    app.dependency_overrides[get_health_service] = lambda: HealthService(
        settings=settings,
        ironic_client=FakeIronicClient(connected=True),
    )
    response = client.get("/health")

    app.dependency_overrides.clear()

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "healthy"
    assert payload["version"] == settings.app_version
    assert "timestamp" in payload
    assert payload["ironic_connected"] is True
    assert payload["ironic_api_version"] == settings.ironic_api_version
