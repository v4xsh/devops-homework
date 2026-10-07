"""TaskBoard API - FastAPI backend of the final DevOps project (based on the instructor's session21-python app).

Operational endpoints:
  GET /health   liveness  - the process is up (no dependencies checked)
  GET /ready    readiness - the database answers a query; 503 otherwise
  GET /metrics  Prometheus metrics (HTTP RED metrics + business counters)
"""
import json
import logging
import sys
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import Counter, Gauge
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func, select, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from .config import settings
from .db import Base, engine, get_db
from .models import Task
from .schemas import StatsOut, TaskCreate, TaskOut, TaskUpdate

# ------------------------------------------------------------------ structured logging
logger = logging.getLogger("taskboard")
_handler = logging.StreamHandler(sys.stdout)
_handler.setFormatter(logging.Formatter("%(message)s"))
logger.addHandler(_handler)
logger.setLevel(settings.log_level.upper())
logger.propagate = False


def log(level: int, msg: str, **fields) -> None:
    logger.log(level, json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "level": logging.getLevelName(level),
                                  "service": "taskboard-backend", "env": settings.app_env, "msg": msg, **fields}))


# ------------------------------------------------------------------ business metrics
TASKS_CREATED = Counter("taskboard_tasks_created_total", "Tasks created", ["priority"])
TASKS_DELETED = Counter("taskboard_tasks_deleted_total", "Tasks deleted")
APP_INFO = Gauge("taskboard_app_info", "Build information", ["version", "env"])
APP_INFO.labels(version=settings.app_version, env=settings.app_env).set(1)


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Containers run `alembic upgrade head` (init container) before the API starts;
    # create_all is a no-op then and keeps tests/local sqlite self-contained.
    try:
        Base.metadata.create_all(bind=engine)
    except SQLAlchemyError as exc:  # DB not reachable yet - /ready will report it
        log(logging.WARNING, "database not reachable at startup", error=str(exc.__class__.__name__))
    log(logging.INFO, "startup complete", version=settings.app_version)
    yield


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
Instrumentator(excluded_handlers=["/metrics", "/health", "/ready"]).instrument(app).expose(
    app, endpoint="/metrics", include_in_schema=False)


@app.middleware("http")
async def access_log(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    if request.url.path not in ("/metrics", "/health", "/ready"):
        log(logging.INFO, "request", method=request.method, path=request.url.path,
            status=response.status_code, duration_ms=round((time.perf_counter() - start) * 1000, 2))
    return response


@app.get("/")
def root():
    return {"service": settings.app_name, "version": settings.app_version, "env": settings.app_env, "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "UP"}


@app.get("/ready")
def ready(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        db.execute(select(func.count(Task.id)))
    except SQLAlchemyError as exc:
        log(logging.ERROR, "readiness check failed", error=exc.__class__.__name__)
        return JSONResponse(status_code=503, content={"status": "NOT_READY", "reason": "database unavailable"})
    return {"status": "READY"}


@app.get("/api/info")
def info():
    return {"service": settings.app_name, "version": settings.app_version, "env": settings.app_env}


@app.get("/api/tasks", response_model=list[TaskOut])
def list_tasks(db: Session = Depends(get_db)):
    return list(db.scalars(select(Task).order_by(Task.id.desc())))


@app.get("/api/tasks/stats", response_model=StatsOut)
def stats(db: Session = Depends(get_db)):
    rows = db.execute(select(Task.status, func.count(Task.id)).group_by(Task.status)).all()
    counts = {s: c for s, c in rows}
    return StatsOut(total=sum(counts.values()), todo=counts.get("TODO", 0),
                    inProgress=counts.get("IN_PROGRESS", 0), done=counts.get("DONE", 0))


@app.get("/api/tasks/{task_id}", response_model=TaskOut)
def get_task(task_id: int, db: Session = Depends(get_db)):
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@app.post("/api/tasks", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskCreate, db: Session = Depends(get_db)):
    task = Task(**payload.model_dump())
    db.add(task)
    db.commit()
    db.refresh(task)
    TASKS_CREATED.labels(priority=task.priority).inc()
    return task


@app.put("/api/tasks/{task_id}", response_model=TaskOut)
def update_task(task_id: int, payload: TaskUpdate, db: Session = Depends(get_db)):
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(task, key, value)
    db.commit()
    db.refresh(task)
    return task


@app.delete("/api/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(task_id: int, db: Session = Depends(get_db)):
    task = db.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    db.delete(task)
    db.commit()
    TASKS_DELETED.inc()
