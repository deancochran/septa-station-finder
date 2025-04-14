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

log = logging.getLogger("uvicorn")


@asynccontextmanager
async def lifespan(app_: FastAPI):
	log.info("Starting up")
	await load_septa_data()
	yield
	await delete_septa_data()
	log.info("Shutting down")



app = FastAPI(lifespan=lifespan)


@app.get("/")
async def root():
    return {"version": app.version, "message": "SEPTA Regional Rail Station Finder API"}


app.include_router(auth.router)
app.include_router(septa.router)
