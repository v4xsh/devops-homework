"""Session 17 - small "secure notes" API used to demonstrate a DevSecOps pipeline.

Endpoints
  GET  /health            -> probe target
  GET  /api/status        -> app name, version, git sha baked in at build time
  GET  /api/notes         -> list notes (in memory)
  POST /api/notes         -> {"title": "...", "body": "..."} with input validation
  GET  /api/notes/<id>    -> one note
"""
import hashlib
import os
import threading

from flask import Flask, jsonify, request

APP_VERSION = "1.0.0"
MAX_TITLE = 80
MAX_BODY = 1000


def create_app() -> Flask:
    flask_app = Flask(__name__)
    # never hard-code secrets: the key comes from the environment (a Kubernetes Secret in prod)
    flask_app.config["SECRET_KEY"] = os.environ.get("APP_SECRET_KEY", os.urandom(32).hex())
    flask_app.config["MAX_CONTENT_LENGTH"] = 16 * 1024

    notes = {}
    lock = threading.Lock()

    @flask_app.after_request
    def security_headers(resp):
        resp.headers["X-Content-Type-Options"] = "nosniff"
        resp.headers["X-Frame-Options"] = "DENY"
        resp.headers["Content-Security-Policy"] = "default-src 'none'"
        return resp

    @flask_app.get("/health")
    def health():
        return jsonify(status="ok")

    @flask_app.get("/api/status")
    def status():
        return jsonify(
            app="s17-devsecops-api",
            version=APP_VERSION,
            git_sha=os.environ.get("GIT_SHA", "dev"),
            notes=len(notes),
        )

    @flask_app.get("/api/notes")
    def list_notes():
        return jsonify(sorted(notes.values(), key=lambda n: n["id"]))

    @flask_app.get("/api/notes/<int:note_id>")
    def get_note(note_id):
        note = notes.get(note_id)
        if note is None:
            return jsonify(error="note not found"), 404
        return jsonify(note)

    @flask_app.post("/api/notes")
    def add_note():
        data = request.get_json(silent=True)
        if not isinstance(data, dict):
            return jsonify(error="JSON object body required"), 400
        title = str(data.get("title", "")).strip()
        body = str(data.get("body", "")).strip()
        if not title or len(title) > MAX_TITLE:
            return jsonify(error=f"title is required (max {MAX_TITLE} chars)"), 400
        if len(body) > MAX_BODY:
            return jsonify(error=f"body too long (max {MAX_BODY} chars)"), 400
        with lock:
            note_id = len(notes) + 1
            note = {
                "id": note_id,
                "title": title,
                "body": body,
                # integrity checksum of the content (SHA-256, not a weak hash like MD5)
                "sha256": hashlib.sha256(f"{title}\n{body}".encode()).hexdigest(),
            }
            notes[note_id] = note
        return jsonify(note), 201

    return flask_app


app = create_app()
