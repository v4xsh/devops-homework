"""Flask HTTP API around the calculator functions.

Endpoints
  GET  /health                         -> liveness/readiness probe target
  GET  /version                        -> app version + git sha baked in at build time
  GET  /api/<operation>?a=<n>&b=<n>    -> add | subtract | multiply | divide
  POST /api/calculate {"operation","a","b"}
"""
import os

from flask import Flask, jsonify, request

from app.calculator import OPERATIONS, calculate

APP_VERSION = "1.0.0"


def create_app() -> Flask:
    flask_app = Flask(__name__)

    @flask_app.get("/health")
    def health():
        return jsonify(status="ok")

    @flask_app.get("/version")
    def version():
        return jsonify(
            app="s16-calculator-api",
            version=APP_VERSION,
            git_sha=os.environ.get("GIT_SHA", "dev"),
        )

    def _compute(operation, a, b):
        try:
            a, b = float(a), float(b)
        except (TypeError, ValueError):
            return jsonify(error="'a' and 'b' must be numbers"), 400
        try:
            result = calculate(operation, a, b)
        except ValueError as exc:
            return jsonify(error=str(exc)), 400
        return jsonify(operation=operation, a=a, b=b, result=result)

    @flask_app.get("/api/<operation>")
    def compute_get(operation):
        if operation not in OPERATIONS:
            return jsonify(error=f"Unknown operation '{operation}'"), 404
        return _compute(operation, request.args.get("a"), request.args.get("b"))

    @flask_app.post("/api/calculate")
    def compute_post():
        data = request.get_json(silent=True) or {}
        return _compute(data.get("operation", "add"), data.get("a"), data.get("b"))

    return flask_app


app = create_app()

if __name__ == "__main__":  # pragma: no cover - local dev only
    app.run(host="127.0.0.1", port=8000)
