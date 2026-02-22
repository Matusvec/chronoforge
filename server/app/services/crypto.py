"""Encrypt / decrypt refresh tokens at rest using Fernet symmetric encryption."""

from cryptography.fernet import Fernet
from app.config import get_settings


def _get_fernet() -> Fernet:
    key = get_settings().token_encryption_key
    if not key:
        key = Fernet.generate_key().decode()
    return Fernet(key.encode() if isinstance(key, str) else key)


def encrypt_token(plaintext: str) -> str:
    return _get_fernet().encrypt(plaintext.encode()).decode()


def decrypt_token(ciphertext: str) -> str:
    return _get_fernet().decrypt(ciphertext.encode()).decode()
