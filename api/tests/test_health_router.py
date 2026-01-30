"""Tests for the health router."""

from fastapi.testclient import TestClient

from config import get_settings


def test_health_endpoint_returns_status(client: TestClient) -> None:
    settings = get_settings()
    response = client.get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "healthy"
    assert payload["version"] == settings.app_version
    assert "timestamp" in payload
