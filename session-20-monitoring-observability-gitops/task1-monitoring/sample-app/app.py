"""s20-metrics-app: a tiny Flask service used to demonstrate monitoring and observability.

Signals it produces:
  * Metrics - Prometheus format on /metrics (request counter, latency histogram, in-flight gauge)
  * Logs    - one JSON line per request on stdout (read with `kubectl logs`)
  * Traces  - OpenTelemetry spans exported over OTLP/HTTP when OTEL_EXPORTER_OTLP_ENDPOINT is set
  * Health  - /healthz (liveness) and /readyz (readiness) for Kubernetes probes
"""
import json
import logging
import os
import random
import sys
import time

from flask import Flask, Response, g, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest

APP_NAME = os.getenv("APP_NAME", "s20-metrics-app")
APP_VERSION = os.getenv("APP_VERSION", "1.1.0")

app = Flask(__name__)

# ---------------------------------------------------------------- logging (JSON to stdout)
log = logging.getLogger(APP_NAME)
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(logging.Formatter("%(message)s"))
log.addHandler(handler)
log.setLevel(os.getenv("LOG_LEVEL", "INFO"))
logging.getLogger("werkzeug").setLevel(logging.WARNING)

# ---------------------------------------------------------------- metrics
REQUESTS = Counter("app_requests_total", "Total HTTP requests", ["method", "endpoint", "status"])
LATENCY = Histogram(
    "app_request_duration_seconds", "HTTP request latency in seconds", ["endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5),
)
IN_PROGRESS = Gauge("app_requests_in_progress", "Requests currently being served")
INFO = Gauge("app_info", "Static build information", ["version"])
INFO.labels(version=APP_VERSION).set(1)

# ---------------------------------------------------------------- tracing (optional)
tracer = None
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"):
    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.flask import FlaskInstrumentor
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    provider = TracerProvider(resource=Resource.create({"service.name": APP_NAME, "service.version": APP_VERSION}))
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
    FlaskInstrumentor().instrument_app(app, excluded_urls="/metrics,/healthz,/readyz")
    tracer = trace.get_tracer(APP_NAME)

READY = {"value": True}


@app.before_request
def _start():
    g.start = time.perf_counter()
    IN_PROGRESS.inc()


@app.after_request
def _finish(response):
    IN_PROGRESS.dec()
    endpoint = request.url_rule.rule if request.url_rule else "unmatched"
    elapsed = time.perf_counter() - g.start
    if endpoint != "/metrics":
        REQUESTS.labels(request.method, endpoint, str(response.status_code)).inc()
        LATENCY.labels(endpoint).observe(elapsed)
        log.info(json.dumps({
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "level": "INFO", "app": APP_NAME,
            "method": request.method, "path": request.path, "status": response.status_code,
            "duration_ms": round(elapsed * 1000, 2), "client": request.remote_addr,
        }))
    return response


@app.get("/")
def index():
    return {"app": APP_NAME, "version": APP_VERSION, "endpoints": ["/work", "/error", "/healthz", "/readyz", "/metrics"]}


@app.get("/work")
def work():
    """Simulates a request that does some CPU work and calls a 'downstream' dependency."""
    n = int(request.args.get("n", "20000"))
    if tracer:
        with tracer.start_as_current_span("compute") as span:
            span.set_attribute("work.n", n)
            total = sum(i * i for i in range(n))
        with tracer.start_as_current_span("downstream-call"):
            time.sleep(random.uniform(0.01, 0.05))
    else:
        total = sum(i * i for i in range(n))
        time.sleep(random.uniform(0.01, 0.05))
    return {"result": total % 1000, "n": n}


@app.get("/error")
def error():
    log.error(json.dumps({"level": "ERROR", "app": APP_NAME, "msg": "simulated failure on /error"}))
    return {"error": "simulated failure"}, 500


@app.get("/healthz")
def healthz():
    return {"status": "UP"}


@app.get("/readyz")
def readyz():
    return ({"status": "READY"}, 200) if READY["value"] else ({"status": "NOT_READY"}, 503)


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))  # nosec B104 - container listens on all interfaces
