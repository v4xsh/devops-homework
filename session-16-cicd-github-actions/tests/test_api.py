import pytest

from app.main import create_app


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


def test_version_uses_git_sha(client, monkeypatch):
    monkeypatch.setenv("GIT_SHA", "abc1234")
    data = client.get("/version").get_json()
    assert data["git_sha"] == "abc1234"
    assert data["version"] == "1.0.0"


def test_add_get(client):
    resp = client.get("/api/add?a=2&b=3")
    assert resp.status_code == 200
    assert resp.get_json()["result"] == 5


def test_divide_by_zero_returns_400(client):
    resp = client.get("/api/divide?a=1&b=0")
    assert resp.status_code == 400
    assert "divide by zero" in resp.get_json()["error"]


def test_unknown_operation_returns_404(client):
    assert client.get("/api/power?a=2&b=3").status_code == 404


def test_non_numeric_returns_400(client):
    assert client.get("/api/add?a=x&b=3").status_code == 400


def test_post_calculate(client):
    resp = client.post("/api/calculate", json={"operation": "multiply", "a": 6, "b": 7})
    assert resp.status_code == 200
    assert resp.get_json()["result"] == 42


def test_post_calculate_bad_operation(client):
    resp = client.post("/api/calculate", json={"operation": "power", "a": 6, "b": 7})
    assert resp.status_code == 400
