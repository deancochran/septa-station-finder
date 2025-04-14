from sqlmodel import Field, SQLModel, select
from pydantic import EmailStr, field_validator
from datetime import datetime, timezone
from passlib.context import CryptContext
from sqlmodel.ext.asyncio.session import AsyncSession
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class BaseUser(SQLModel):
    username: str = Field(min_length=3, max_length=50, index=True, unique=True)
    email: EmailStr = Field(index=True, unique=True)
    password: str = Field(min_length=8)

    @field_validator("username")
    def username_must_be_valid(cls, v):
        if not v.isalnum():
            raise ValueError("Username must contain only alphanumeric characters")
        return v

    @field_validator("password")
    def password_must_be_strong(cls, v):
        if not any(char.isdigit() for char in v):
            raise ValueError("Password must contain at least one number")
        if not any(char.isupper() for char in v):
            raise ValueError("Password must contain at least one uppercase letter")
        return v


class User(BaseUser, table=True):
    id: int | None = Field(default=None, primary_key=True)
    created_at: datetime = Field(default_factory=datetime.now)

    async def create(self, db: AsyncSession):
        self.password = self.get_hashed_password(self.password)
        db.add(self)
        await db.flush()
        return self

    @staticmethod
    def get_hashed_password(password):
        return pwd_context.hash(password)

    @staticmethod
    def verify_password(password, hashed_password):
        return pwd_context.verify(password, hashed_password)


    @staticmethod
    async def get_user_by_username(username: str, db: AsyncSession):
        result = await db.exec(select(User).where(User.username == username))
        return result.first()
