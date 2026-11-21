"""Tests for the /ui page: it works, and it cannot talk to the AI model directly."""
import os

os.environ.setdefault("DATABASE_URL", "postgresql://test:test@localhost:5432/test")

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_ui_page_has_summary_button():
    response = client.get("/ui/")
    assert response.status_code == 200
    assert 'id="summary-button"' in response.text


def test_ui_page_allows_requests_only_to_our_server():
    csp = client.get("/ui/").headers["Content-Security-Policy"]
    assert "connect-src 'self'" in csp
    assert "script-src 'self'" in csp


def test_browser_code_never_contacts_the_model():
    script = client.get("/ui/app.js").text
    assert 'fetch("/entries/summary"' in script  # it calls our backend...
    for forbidden in ["openai.azure.com", "cognitiveservices", "api-key", "Authorization"]:
        assert forbidden not in script  # ...and nothing that leads to the model
