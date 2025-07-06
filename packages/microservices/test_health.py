"""
Basic health test for microservices package
"""
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_health_endpoint():
    """Test that the health endpoint returns 200"""
    response = client.get("/health")
    assert response.status_code == 200
    assert "status" in response.json()


def test_root_endpoint():
    """Test that the root endpoint returns 200"""
    response = client.get("/")
    assert response.status_code == 200


def test_app_creation():
    """Test that the FastAPI app can be created"""
    assert app is not None
    assert hasattr(app, "title")
