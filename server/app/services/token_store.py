"""
In-memory token store for MVP. In production, swap for a database.
Tokens are encrypted at rest via Fernet.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from app.services.crypto import encrypt_token, decrypt_token


@dataclass
class UserTokens:
    google_access_token: str | None = None
    google_refresh_token_enc: str | None = None
    canvas_access_token: str | None = None
    email: str | None = None

    def set_google_refresh(self, token: str) -> None:
        self.google_refresh_token_enc = encrypt_token(token)

    def get_google_refresh(self) -> str | None:
        if self.google_refresh_token_enc:
            return decrypt_token(self.google_refresh_token_enc)
        return None


@dataclass
class TokenStore:
    _users: dict[str, UserTokens] = field(default_factory=dict)

    def get_or_create(self, user_id: str) -> UserTokens:
        if user_id not in self._users:
            self._users[user_id] = UserTokens()
        return self._users[user_id]

    def get(self, user_id: str) -> UserTokens | None:
        return self._users.get(user_id)


store = TokenStore()
