import logging
import time

from dotenv import load_dotenv
from fastapi import FastAPI, Request, Response
from fastapi.responses import RedirectResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

from routers.journal_router import router as journal_router

load_dotenv()

# Configure basic console logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

app = FastAPI(title="LearningSteps API", description="A simple learning journal API for tracking daily work, struggles, and intentions")
app.include_router(journal_router)

# --- Monitoring: two Prometheus metrics ---
# Counter = a number that only goes up: how many requests came in
HTTP_REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
# Histogram = how long requests took, sorted into time buckets
HTTP_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
)


@app.middleware("http")
async def record_metrics(request: Request, call_next):
    """Runs around every request: starts a stopwatch, lets the request through, then records it."""
    start = time.perf_counter()
    status = "500"  # if the app crashes, we still count the request as an error
    try:
        response = await call_next(request)
        status = str(response.status_code)
        return response
    finally:
        route = request.scope.get("route")
        endpoint = route.path if route else "unmatched"
        HTTP_REQUESTS.labels(request.method, endpoint, status).inc()
        HTTP_LATENCY.labels(request.method, endpoint).observe(time.perf_counter() - start)


@app.get("/health", tags=["ops"])
def health():
    """Liveness check: answers as long as the app process is running."""
    return {"status": "ok"}


@app.get("/metrics", include_in_schema=False)
def metrics():
    """Prometheus reads all counters and timings from here."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")


# Log when the app starts
logger.info("LearningSteps API started successfully")