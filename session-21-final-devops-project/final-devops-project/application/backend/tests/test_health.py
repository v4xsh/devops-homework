def test_health_is_up(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "UP"}


def test_ready_checks_database(client):
    r = client.get("/ready")
    assert r.status_code == 200
    assert r.json()["status"] == "READY"


def test_root_and_info(client):
    assert client.get("/").json()["service"] == "TaskBoard API"
    info = client.get("/api/info").json()
    assert info["env"] == "test"
    assert "version" in info


def test_metrics_endpoint_exposes_prometheus_format(client):
    client.post("/api/tasks", json={"title": "metric me", "priority": "LOW"})
    client.get("/api/tasks")
    body = client.get("/metrics").text
    assert "http_requests_total" in body
    assert 'taskboard_tasks_created_total{priority="LOW"}' in body
    assert "taskboard_app_info" in body


def test_ready_returns_503_when_database_down(client):
    from sqlalchemy.exc import OperationalError

    from app.db import get_db
    from app.main import app

    class BrokenSession:
        def execute(self, *_a, **_k):
            raise OperationalError("SELECT 1", {}, Exception("connection refused"))

    app.dependency_overrides[get_db] = lambda: BrokenSession()
    try:
        r = client.get("/ready")
    finally:
        app.dependency_overrides.clear()
    assert r.status_code == 503
    assert r.json()["status"] == "NOT_READY"
