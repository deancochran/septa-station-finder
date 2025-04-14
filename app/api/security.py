from datetime import datetime, timedelta, timezone
from fastapi.security import OAuth2PasswordBearer
import jwt
from sqlmodel import SQLModel

from app.api.exceptions import INVALID_CREDENTIALS
from app.core.settings import settings
from app.models.user import User

OAUTH2_SCHEME = OAuth2PasswordBearer(tokenUrl="/auth/login")

class TokenData(SQLModel):
    sub: str
    exp: datetime

class Token(SQLModel):
    access_token: str
    token_type: str 

def create_jwt_token(user:User)->Token:
    token_data = TokenData(
        sub=user.username,
        exp=datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    ).model_dump()
    return Token(
        access_token= jwt.encode(token_data, settings.SECRET_KEY, algorithm=settings.ALGORITHM),
        token_type="bearer"
    )

def validate_jwt_token(token:str)-> TokenData:
    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    token_data = TokenData(**payload)
    if token_data.sub is None:
        raise INVALID_CREDENTIALS
    if token_data.exp < datetime.now(timezone.utc):
        raise INVALID_CREDENTIALS
    return token_data
