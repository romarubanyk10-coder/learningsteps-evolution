import os

# The app refuses to start without DATABASE_URL. The tests never connect to it.
os.environ.setdefault("DATABASE_URL", "postgresql://test:test@localhost:5432/test")

import pytest
from fastapi.testclient import TestClient
from main import app
from routers.journal_router import get_entry_service


class FakeEntryService:
    """Stands in for the real database: keeps entries in a Python dictionary."""

    def __init__(self):
        self.entries = {}

    async def create_entry(self, entry_data):
        self.entries[entry_data["id"]] = entry_data
        return entry_data

    async def get_all_entries(self):
        return list(self.entries.values())

    async def get_entry(self, entry_id):
        return self.entries.get(entry_id)

    async def delete_entry(self, entry_id):
        self.entries.pop(entry_id, None)


@pytest.fixture
def client():
    """A test 'browser' that talks to the app, with the fake database plugged in."""
    fake = FakeEntryService()
    app.dependency_overrides[get_entry_service] = lambda: fake
    yield TestClient(app)
    app.dependency_overrides.clear()


VALID_ENTRY = {
    "work": "Learned Docker",
    "struggle": "Multi-stage builds",
    "intention": "Write the Dockerfile",
}


def test_health_returns_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_metrics_counts_requests(client):
    client.get("/health")
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text


def test_create_and_read_entry(client):
    created = client.post("/entries", json=VALID_ENTRY)
    assert created.status_code == 200
    entry_id = created.json()["entry"]["id"]

    read = client.get(f"/entries/{entry_id}")
    assert read.status_code == 200
    assert read.json()["work"] == "Learned Docker"


def test_unknown_entry_returns_404(client):
    response = client.get("/entries/does-not-exist")
    assert response.status_code == 404


def test_too_short_text_is_rejected(client):
    response = client.post("/entries", json={**VALID_ENTRY, "work": "ab"})
    assert response.status_code == 422