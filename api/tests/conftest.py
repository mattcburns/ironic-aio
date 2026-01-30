"""Pytest fixtures."""

import pytest
from fastapi.testclient import TestClient

from app import app


@pytest.fixture()
def client() -> TestClient:
    """Create a FastAPI test client."""

    return TestClient(app)
