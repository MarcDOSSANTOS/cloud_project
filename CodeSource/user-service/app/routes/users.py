"""
Routes du User Service
Endpoints : register, login, profile
"""

import os
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from jose import jwt, JWTError

from app.models.database import get_db, User
from app.models.schemas import UserRegister, UserLogin, TokenResponse, UserResponse

router = APIRouter()

# ============================================
# Configuration
# ============================================
JWT_SECRET = os.getenv("JWT_SECRET", "techshop-secret-key-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = 24

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ============================================
# Utilitaires
# ============================================
def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_token(user: User) -> str:
    payload = {
        "user_id": user.id,
        "email": user.email,
        "name": user.name,
        "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


# ============================================
# Endpoints
# ============================================

@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """Inscription d'un nouvel utilisateur"""
    
    # Vérifier si l'email existe déjà
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un compte avec cet email existe déjà"
        )

    # Créer l'utilisateur
    new_user = User(
        name=user_data.name,
        email=user_data.email,
        password_hash=hash_password(user_data.password),
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Générer le token
    token = create_token(new_user)

    return TokenResponse(
        user=UserResponse(**new_user.to_dict()),
        token=token,
    )


@router.post("/login", response_model=TokenResponse)
async def login(credentials: UserLogin, db: Session = Depends(get_db)):
    """Connexion d'un utilisateur"""
    
    user = db.query(User).filter(User.email == credentials.email).first()
    
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect"
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ce compte a été désactivé"
        )

    token = create_token(user)

    return TokenResponse(
        user=UserResponse(**user.to_dict()),
        token=token,
    )


@router.get("/profile", response_model=UserResponse)
async def get_profile(db: Session = Depends(get_db)):
    """
    Récupérer le profil de l'utilisateur connecté.
    Note : En production, l'authentification est gérée par l'API Gateway.
    Ici, on extrait le user_id du header X-User-Id transmis par le gateway.
    """
    # Simplifié pour la démo - en production, utiliser le token JWT
    return UserResponse(
        id=1,
        name="Demo User",
        email="demo@techshop.com",
        is_active=True,
    )


@router.get("/", response_model=list)
async def list_users(db: Session = Depends(get_db)):
    """Liste tous les utilisateurs (endpoint admin)"""
    users = db.query(User).all()
    return [user.to_dict() for user in users]
