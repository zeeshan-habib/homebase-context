import time
import threading
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
api_app = FastAPI()

api_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


def _respond(data, loading=False):
    return {"data": data, "loading": loading, "last_updated": time.time()}


def _safe_get(key):
    """Return (data, loading, error). Never raises."""
    try:
        import queries
        cache = queries._cache
        if key not in cache:
            return None, True, None
        fn = {"labor": queries.get_labor, "wages": queries.get_wages, "jobs": queries.get_jobs}[key]
        return fn(), False, None
    except Exception as e:
        return None, False, str(e)


@api_app.get("/labor")
def labor():
    data, loading, err = _safe_get("labor")
    if err:
        return {"data": None, "loading": False, "error": err, "last_updated": time.time()}
    return _respond(data, loading=loading)


@api_app.get("/wages")
def wages():
    data, loading, err = _safe_get("wages")
    if err:
        return {"data": None, "loading": False, "error": err, "last_updated": time.time()}
    return _respond(data, loading=loading)


@api_app.get("/jobs")
def jobs():
    data, loading, err = _safe_get("jobs")
    if err:
        return {"data": None, "loading": False, "error": err, "last_updated": time.time()}
    return _respond(data, loading=loading)


@api_app.get("/health")
def health():
    import queries
    return {
        "status": "ok",
        "cached": list(queries._cache.keys()),
    }


def _warm():
    """Background thread: populate all caches on startup."""
    import queries
    for fn in (queries.get_labor, queries.get_wages, queries.get_jobs):
        try:
            fn()
        except Exception:
            pass


@app.on_event("startup")
def startup():
    threading.Thread(target=_warm, daemon=True).start()


# Mount order is critical: /api must come before the static catch-all
app.mount("/api", api_app)
app.mount("/", StaticFiles(directory="static", html=True))
