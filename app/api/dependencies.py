from typing import Annotated
from fastapi import Depends
from jwt import InvalidTokenError
from sqlmodel.ext.asyncio.session import AsyncSession
from app.api.exceptions import INVALID_CREDENTIALS
from app.api.security import OAUTH2_SCHEME, validate_jwt_token
from app.core.config import get_database_client

from app.models.user import User



async def authenticated_user(token: Annotated[str, Depends(OAUTH2_SCHEME)], db: AsyncSession = Depends(get_database_client)):
    try:
        token_data = validate_jwt_token(token)
    except InvalidTokenError:
        raise INVALID_CREDENTIALS
    user = await User.get_user_by_username(username=token_data.sub, db=db)
    if not user:
        raise INVALID_CREDENTIALS
    return user
