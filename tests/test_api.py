import os

# The app refuses to start without DATABASE_URL. The tests never connect to it.
os.environ.setdefault("DATABASE_URL", "postgresql://test:test@localhost:5432/test")

import pytest
from fastapi.testclient import TestClient
from main import app
from routers.journal_router import get_entry_service
from services.entry_service import EntryService


class FakeDB:
    """Stands in for PostgreSQL: keeps rows in a Python dictionary.

    It behaves like the real database class: an update replaces the stored
    data completely, exactly as the SQL UPDATE in postgres_repository.py does.
    """

    def __init__(self):
        self.rows = {}

    def _clean(self, data):
        return {
            "id": data["id"],
            "work": data.get("work", ""),
            "struggle": data.get("struggle", ""),
            "intention": data.get("intention", ""),
            "created_at": data.get("created_at"),
            "updated_at": data.get("updated_at"),
        }

    async def create_entry(self, entry_data):
        self.rows[entry_data["id"]] = dict(entry_data)
        return self._clean(entry_data)

    async def get_all_entries(self):
        return [self._clean(row) for row in self.rows.values()]

    async def get_entry(self, entry_id):
        row = self.rows.get(entry_id)
        return self._clean(row) if row else None

    async def update_entry(self, entry_id, updated_data):
        self.rows[entry_id] = dict(updated_data)

    async def delete_entry(self, entry_id):
        self.rows.pop(entry_id, None)

    async def delete_all_entries(self):
        self.rows.clear()


@pytest.fixture
def client():
    """A test 'browser' for the app: the real code runs, only the database is fake."""
    fake_db = FakeDB()
    app.dependency_overrides[get_entry_service] = lambda: EntryService(fake_db)
    yield TestClient(app)
    app.dependency_overrides.clear()


VALID_ENTRY = {
    "work": "Learned Docker",
    "struggle": "Multi-stage builds",
    "intention": "Write the Dockerfile",
}


def create_entry(client):
    """Helper: create one entry and return its id."""
    response = client.post("/entries", json=VALID_ENTRY)
    assert response.status_code == 200
    return response.json()["entry"]["id"]


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
    entry_id = create_entry(client)
    read = client.get(f"/entries/{entry_id}")
    assert read.status_code == 200
    assert read.json()["work"] == "Learned Docker"


def test_unknown_entry_returns_404(client):
    response = client.get("/entries/does-not-exist")
    assert response.status_code == 404


def test_too_short_text_is_rejected(client):
    response = client.post("/entries", json={**VALID_ENTRY, "work": "ab"})
    assert response.status_code == 422


def test_patch_keeps_fields_that_were_not_sent(client):
    entry_id = create_entry(client)
    client.patch(f"/entries/{entry_id}", json={"work": "Learned Kubernetes"})
    entry = client.get(f"/entries/{entry_id}").json()
    assert entry["work"] == "Learned Kubernetes"
    assert entry["struggle"] == "Multi-stage builds"
    assert entry["intention"] == "Write the Dockerfile"


def test_patch_rejects_too_short_text(client):
    entry_id = create_entry(client)
    response = client.patch(f"/entries/{entry_id}", json={"work": "ab"})
    assert response.status_code == 422