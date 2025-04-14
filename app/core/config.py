from fastapi import HTTPException
import redis
from app.core.settings import settings

from sqlmodel.ext.asyncio.session import AsyncSession
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.orm import sessionmaker

from sqlalchemy.orm import sessionmaker

from app.models import *  # noqa

# Create an AsyncEngine instance
db_engine = create_async_engine(settings.DATABASE_URL, echo=True, future=True)

# NOTE: Used for SQLite only
async def create_all():
    # This is the proper way to create tables with SQLModel asynchronously
    # async with db_engine.begin() as conn:
        # SQLModel.metadata.create_all needs direct engine connection
        # await conn.run_sync(SQLModel.metadata.create_all)
    pass

# NOTE: Used for SQLite only
async def drop_all():
    # Similarly for dropping tables
    # async with db_engine.begin() as conn:
        # await conn.run_sync(SQLModel.metadata.drop_all)
    pass

async def get_database_client():
    async_session = sessionmaker(
        bind=db_engine, class_=AsyncSession, expire_on_commit=False
    )
    async with async_session() as db:
        
        yield db
        try:
            await db.commit()
        except Exception as e:
            await db.rollback()
            raise HTTPException(status_code=500, detail=str(e))
        finally:
            await db.close()


# Redis connection with error handling
def get_redis_client():
    # Connect to Redis with a timeout to prevent hanging
    try:
        redis_client = redis.from_url(
            settings.REDIS_URL, 
            decode_responses=True,
            socket_timeout=2,
            socket_connect_timeout=2
        )
        # Quick test connection
        redis_client.ping()
        yield redis_client
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
