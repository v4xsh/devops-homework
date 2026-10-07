import hashlib

import pytest

from app.main import MAX_TITLE, create_app


@pytest.fixture
def client():
    flask_app = create_app()
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as test_client:
        yield test_client


def test_health(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_security_headers_present(client):
    resp = client.get("/health")
    assert resp.headers["X-Content-Type-Options"] == "nosniff"
    assert resp.headers["X-Frame-Options"] == "DENY"
    assert resp.headers["Content-Security-Policy"] == "default-src 'none'"


def test_status_reports_git_sha(client, monkeypatch):
    monkeypatch.setenv("GIT_SHA", "abc1234")
    data = client.get("/api/status").get_json()
    assert data["git_sha"] == "abc1234"
    assert data["app"] == "s17-devsecops-api"


def test_create_and_get_note(client):
    resp = client.post("/api/notes", json={"title": "hello", "body": "world"})
    assert resp.status_code == 201
    note = resp.get_json()
    assert note["id"] == 1
    assert note["sha256"] == hashlib.sha256(b"hello\nworld").hexdigest()
    assert client.get("/api/notes/1").get_json()["title"] == "hello"
    assert len(client.get("/api/notes").get_json()) == 1


def test_missing_note_returns_404(client):
    assert client.get("/api/notes/99").status_code == 404


@pytest.mark.parametrize(
    "payload",
    [None, [], {"title": ""}, {"title": "x" * (MAX_TITLE + 1)}, {"title": "ok", "body": "y" * 1001}],
)
def test_input_validation(client, payload):
    if payload is None:
        resp = client.post("/api/notes", data="not json", content_type="text/plain")
    else:
        resp = client.post("/api/notes", json=payload)
    assert resp.status_code == 400


def test_secret_key_comes_from_environment(monkeypatch):
    monkeypatch.setenv("APP_SECRET_KEY", "from-env-for-test")
    assert create_app().config["SECRET_KEY"] == "from-env-for-test"
