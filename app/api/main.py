import asyncio
from contextlib import asynccontextmanager
import logging
from fastapi import  FastAPI, Request, status
from fastapi.responses import  JSONResponse
from sqlalchemy.exc import IntegrityError
from alembic.config import Config
from alembic import command
from app.api.routers import auth, septa
from app.api.utils import load_septa_data, delete_septa_data
from app.core.config import db_engine
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

log = logging.getLogger("uvicorn")

@asynccontextmanager
async def lifespan(app_: FastAPI):
	log.info("Starting up")
	await load_septa_data()
	yield
	await delete_septa_data()
	log.info("Shutting down")


limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])

app = FastAPI(lifespan=lifespan)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler) # type: ignore
app.add_middleware(SlowAPIMiddleware)

@app.get("/")
async def root(request: Request):
    return {"version": app.version, "message": "SEPTA Station Finder API"}


app.include_router(auth.router)
app.include_router(septa.router)
