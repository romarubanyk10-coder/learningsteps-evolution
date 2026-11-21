"""Tests for the AI summary feature, written BEFORE the feature (TDD).

The real model in Azure is replaced by FakeModelClient: an "actor" that
answers with a fixed sentence and remembers what it was asked. So the tests
are fast, free, work offline and need no Azure login.
"""
import os

# The app refuses to start without DATABASE_URL. The tests never connect to it.
os.environ.setdefault("DATABASE_URL", "postgresql://test:test@localhost:5432/test")

from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from main import app
from routers.journal_router import get_entry_service, get_summary_service
from services.summary_service import MAX_ENTRIES, SummaryService


class FakeEntryService:
    """Returns a fixed list of entries instead of reading PostgreSQL."""

    def __init__(self, entries):
        self.entries = entries

    async def get_all_entries(self):
        return self.entries


class FakeModelClient:
    """Pretends to be the OpenAI client: client.chat.completions.create(...)."""

    def __init__(self, answer="You practised Kubernetes and plan CI/CD next.", error=None):
        self.answer = answer
        self.error = error
        self.calls = []  # every request the app sent to the "model"
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

    async def _create(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        message = SimpleNamespace(content=self.answer)
        return SimpleNamespace(choices=[SimpleNamespace(message=message)])


def make_entries(count):
    return [
        {
            "id": f"id-{i}",
            "work": f"work {i}",
            "struggle": f"struggle {i}",
            "intention": f"intention {i}",
            "created_at": f"2026-11-{(i % 28) + 1:02d}T10:00:00+00:00",
            "updated_at": None,
        }
        for i in range(count)
    ]


@pytest.fixture
def setup_app():
    """Builds a test 'browser' with fake entries and a fake model."""

    def _setup(entries, model):
        app.dependency_overrides[get_entry_service] = lambda: FakeEntryService(entries)
        app.dependency_overrides[get_summary_service] = lambda: SummaryService(model, "gpt-5-mini")
        return TestClient(app)

    yield _setup
    app.dependency_overrides.clear()


def test_summary_returns_model_text(setup_app):
    model = FakeModelClient()
    client = setup_app(make_entries(2), model)

    response = client.post("/entries/summary")

    assert response.status_code == 200
    assert response.json() == {
        "summary": "You practised Kubernetes and plan CI/CD next.",
        "entries_used": 2,
    }
    # The backend asked the right deployment, and the entries reached the model
    assert model.calls[0]["model"] == "gpt-5-mini"
    sent_text = str(model.calls[0]["messages"])
    assert "work 0" in sent_text and "intention 1" in sent_text


def test_entries_are_sent_as_data_not_as_instructions(setup_app):
    model = FakeModelClient()
    client = setup_app(make_entries(1), model)

    client.post("/entries/summary")

    messages = model.calls[0]["messages"]
    # Our rules live in the system message; the user's notes only in the user message
    assert messages[0]["role"] == "system"
    assert "work 0" not in messages[0]["content"]
    assert messages[1]["role"] == "user"
    assert "work 0" in messages[1]["content"]


def test_only_the_newest_entries_are_sent(setup_app):
    model = FakeModelClient()
    client = setup_app(make_entries(MAX_ENTRIES + 5), model)

    response = client.post("/entries/summary")

    assert response.json()["entries_used"] == MAX_ENTRIES


def test_no_entries_gives_404_and_no_model_call(setup_app):
    model = FakeModelClient()
    client = setup_app([], model)

    response = client.post("/entries/summary")

    assert response.status_code == 404
    assert model.calls == []  # no cost when there is nothing to summarize


def test_model_error_gives_502_without_details(setup_app):
    model = FakeModelClient(error=RuntimeError("internal detail: token=abc123"))
    client = setup_app(make_entries(1), model)

    response = client.post("/entries/summary")

    assert response.status_code == 502
    assert "abc123" not in response.text  # internal errors never reach the browser


def test_missing_ai_settings_give_503(monkeypatch):
    monkeypatch.delenv("AZURE_OPENAI_BASE_URL", raising=False)
    monkeypatch.delenv("AZURE_OPENAI_DEPLOYMENT", raising=False)
    app.dependency_overrides[get_entry_service] = lambda: FakeEntryService(make_entries(1))
    try:
        response = TestClient(app).post("/entries/summary")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 503
