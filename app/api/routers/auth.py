from typing import Annotated
from fastapi.security import OAuth2PasswordRequestForm
from sqlmodel import SQLModel, update
from sqlmodel.ext.asyncio.session import AsyncSession
from app.api.security import Token, create_jwt_token
from app.core.config import get_database_client
from fastapi import APIRouter, Depends, HTTPException

from app.models.user import BaseUser, User


router = APIRouter(
    prefix="/auth", tags=["auth"], dependencies=[Depends(get_database_client)]
)

class Login(SQLModel):
    username:str
    password:str

@router.post("/login", response_model=Token)
async def login(form_data: Annotated[OAuth2PasswordRequestForm, Depends()], db: Annotated[AsyncSession, Depends(get_database_client)]):
    """
    Authenticate a user and generate an access token.

    This endpoint handles user authentication by verifying the provided username and password.
    If credentials are valid, it returns a JWT token for use in subsequent authenticated requests.

    Parameters:
    - form_data: OAuth2 form containing username and password
    - db: Database session (automatically injected)

    Returns:
    - Token: Object containing the JWT access token and token type

    Raises:
    - 400 Error: If username doesn't exist or password is incorrect
    """
    user = await User.get_user_by_username(form_data.username, db)
    if not user:
        raise HTTPException(
            status_code=400, detail="Incorrect username or password",headers={"WWW-Authenticate": "Bearer"},
        )
    if not User.verify_password(form_data.password, user.password):
        raise HTTPException(
            status_code=400, detail="Incorrect username or password",headers={"WWW-Authenticate": "Bearer"},
        )

    return create_jwt_token(user)


@router.post("/register", response_model=Token)
async def register(form_data: BaseUser, db: AsyncSession = Depends(get_database_client)):
    """
    Register a new user in the system.

    This endpoint creates a new user account using the provided registration information.
    Upon successful registration, it returns a JWT token for immediate authentication.

    Parameters:
    - form_data: BaseUser object containing registration details (username, password, etc.)
    - db: Database session (automatically injected)

    Returns:
    - Token: Object containing the JWT access token and token type for the newly registered user

    Raises:
    - HTTP exceptions may be raised during user creation if validation fails
    """
    user = await User.model_validate(form_data).create(db)
    return create_jwt_token(user)
