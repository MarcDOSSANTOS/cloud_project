"""
Schémas Pydantic pour la validation des données
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class UserRegister(BaseModel):
    name: str = Field(..., min_length=2, max_length=100, examples=["Jean Dupont"])
    email: str = Field(..., examples=["jean.dupont@email.com"])
    password: str = Field(..., min_length=8, examples=["motdepasse123"])


class UserLogin(BaseModel):
    email: str = Field(..., examples=["jean.dupont@email.com"])
    password: str = Field(..., examples=["motdepasse123"])


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    is_active: bool
    created_at: Optional[datetime] = None


class TokenResponse(BaseModel):
    user: UserResponse
    token: str
    token_type: str = "bearer"


class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    email: Optional[str] = None
