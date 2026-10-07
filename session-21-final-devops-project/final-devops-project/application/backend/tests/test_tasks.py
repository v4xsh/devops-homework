def _create(client, **overrides):
    payload = {"title": "Deploy application", "priority": "HIGH", "assignee": "Vansh"}
    payload.update(overrides)
    r = client.post("/api/tasks", json=payload)
    assert r.status_code == 201, r.text
    return r.json()


def test_create_and_get_task(client):
    task = _create(client)
    assert task["id"] > 0 and task["status"] == "TODO"
    r = client.get(f"/api/tasks/{task['id']}")
    assert r.status_code == 200
    assert r.json()["title"] == "Deploy application"


def test_list_tasks_newest_first(client):
    _create(client, title="first")
    _create(client, title="second")
    titles = [t["title"] for t in client.get("/api/tasks").json()]
    assert titles == ["second", "first"]


def test_update_task_status(client):
    task = _create(client)
    r = client.put(f"/api/tasks/{task['id']}", json={"status": "IN_PROGRESS"})
    assert r.status_code == 200
    assert r.json()["status"] == "IN_PROGRESS"
    assert r.json()["title"] == task["title"]  # partial update keeps other fields


def test_delete_task(client):
    task = _create(client)
    assert client.delete(f"/api/tasks/{task['id']}").status_code == 204
    assert client.get(f"/api/tasks/{task['id']}").status_code == 404


def test_stats_counts_by_status(client):
    a = _create(client, title="a")
    _create(client, title="b")
    c = _create(client, title="c")
    client.put(f"/api/tasks/{a['id']}", json={"status": "DONE"})
    client.put(f"/api/tasks/{c['id']}", json={"status": "IN_PROGRESS"})
    assert client.get("/api/tasks/stats").json() == {"total": 3, "todo": 1, "inProgress": 1, "done": 1}


def test_missing_task_returns_404(client):
    assert client.get("/api/tasks/9999").status_code == 404
    assert client.put("/api/tasks/9999", json={"status": "DONE"}).status_code == 404
    assert client.delete("/api/tasks/9999").status_code == 404


def test_validation_rejects_bad_payload(client):
    assert client.post("/api/tasks", json={"title": ""}).status_code == 422
    assert client.post("/api/tasks", json={"title": "x", "priority": "URGENT"}).status_code == 422
    assert client.post("/api/tasks", json={"title": "x", "status": "BLOCKED"}).status_code == 422
