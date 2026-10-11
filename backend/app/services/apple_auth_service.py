import hashlib
import secrets
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from cryptography.fernet import Fernet, InvalidToken

from app.core.exceptions import (
    AuthenticationError,
    ExternalServiceError,
    InvalidStateError,
    ServiceUnavailableError,
)
from app.integrations.social_auth_client import (
    SocialAuthClient,
    SocialAuthInvalidCredentialError,
    SocialAuthNotConfiguredError,
    SocialAuthTimeoutError,
    SocialAuthUpstreamError,
    SocialProfile,
)
from app.models.apple_auth import AppleAuthChallenge
from app.models.social_identity import SocialIdentity
from app.repositories.apple_auth_repository import AppleAuthRepository
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import AppleChallengeRead, AppleTokenRequest


@dataclass(frozen=True)
class VerifiedAppleLogin:
    profile: SocialProfile
    encrypted_refresh_token: str = field(repr=False)
    client_id: str


class AppleAuthService:
    def __init__(
        self,
        *,
        repository: AppleAuthRepository,
        client: SocialAuthClient,
        user_repository: UserRepository,
        auth_session_repository: AuthSessionRepository,
    ) -> None:
        self.repository = repository
        self.client = client
        self.user_repository = user_repository
        self.auth_session_repository = auth_session_repository

    def _configuration(self) -> tuple[str, Fernet]:
        try:
            client_id = self.client.apple_client_id()
            key = self.client.config.apple_token_encryption_key
            if key is None:
                raise SocialAuthNotConfiguredError
            return client_id, Fernet(key.get_secret_value().encode())
        except (SocialAuthNotConfiguredError, ValueError, TypeError) as exc:
            raise ServiceUnavailableError("Apple authentication is not configured") from exc

    async def create_challenge(
        self, *, purpose: str, user_id: int | None = None
    ) -> AppleChallengeRead:
        self._configuration()
        try:
            if purpose == "upgrade":
                user = await self.user_repository.get(user_id) if user_id is not None else None
                if user is None:
                    raise AuthenticationError()
                if not user.is_guest:
                    raise InvalidStateError("Only guest users can be upgraded")
            elif purpose != "login" or user_id is not None:
                raise InvalidStateError("Invalid Apple authentication purpose")
            now = datetime.now(UTC)
            nonce = secrets.token_urlsafe(32)
            challenge = AppleAuthChallenge(
                id=uuid4(),
                nonce_hash=hashlib.sha256(nonce.encode()).hexdigest(),
                purpose=purpose,
                user_id=user_id,
                expires_at=now + timedelta(minutes=5),
            )
            await self.repository.create_challenge(challenge, now=now)
            response = AppleChallengeRead(
                challenge_id=challenge.id, nonce=nonce, expires_at=challenge.expires_at
            )
            await self.repository.session.commit()
            return response
        except Exception:
            await self.repository.session.rollback()
            raise

    async def authenticate(
        self, payload: AppleTokenRequest, *, purpose: str, user_id: int | None = None
    ) -> VerifiedAppleLogin:
        client_id, cipher = self._configuration()
        try:
            nonce_hash = await self.repository.consume_challenge(
                challenge_id=payload.challenge_id,
                purpose=purpose,
                user_id=user_id,
                now=datetime.now(UTC),
            )
            if nonce_hash is None:
                raise AuthenticationError("Invalid or expired Apple login challenge")
            # Codes are single-use upstream. Failed exchanges must start a new sign-in,
            # rather than making this challenge reusable after a local rollback.
            await self.repository.session.commit()
        except Exception:
            await self.repository.session.rollback()
            raise
        try:
            profile = await self.client.verify_apple_identity(
                payload.token, nonce_hash=nonce_hash, display_name=payload.display_name
            )
            grant = await self.client.exchange_apple_code(payload.authorization_code)
            exchanged_profile = await self.client.verify_apple_identity(
                grant.id_token, nonce_hash=nonce_hash, access_token=grant.access_token
            )
            if exchanged_profile.subject != profile.subject:
                raise SocialAuthInvalidCredentialError
            if grant.refresh_token is None:
                raise SocialAuthUpstreamError
            encrypted = cipher.encrypt(grant.refresh_token.encode()).decode()
            return VerifiedAppleLogin(
                profile=profile, encrypted_refresh_token=encrypted, client_id=client_id
            )
        except SocialAuthNotConfiguredError as exc:
            raise ServiceUnavailableError("Apple authentication is not configured") from exc
        except SocialAuthInvalidCredentialError as exc:
            raise AuthenticationError("Invalid Apple authentication credential") from exc
        except (SocialAuthTimeoutError, SocialAuthUpstreamError) as exc:
            raise ExternalServiceError("Apple authentication provider unavailable") from exc

    async def save_login(self, identity: SocialIdentity, login: VerifiedAppleLogin) -> None:
        await self.repository.save_credential(
            identity_id=identity.id,
            client_id=login.client_id,
            encrypted_token=login.encrypted_refresh_token,
            verified_at=datetime.now(UTC),
        )

    async def lock_user_for_refresh(self, refresh_token_hash: str) -> None:
        user_id = await self.repository.apple_user_for_refresh(refresh_token_hash)
        if user_id is not None:
            # All Apple refreshes acquire the user before any session/credential row.
            # A revocation can therefore revoke every session without a lock-order cycle.
            await self.user_repository.get_for_update(user_id)

    async def validate_refresh(self, user_id: int) -> None:
        identity = await self.repository.get_identity(user_id)
        if identity is None:
            return
        client_id, cipher = self._configuration()
        credential = await self.repository.get_credential(identity.id)
        now = datetime.now(UTC)
        if credential is None or credential.revoked_at or not credential.refresh_token_encrypted:
            await self._revoke_sessions(user_id, credential, now)
        if credential.client_id != client_id:
            raise ServiceUnavailableError("Apple authentication configuration has changed")
        if credential.last_verified_at + timedelta(hours=24) > now:
            return
        try:
            provider_token = cipher.decrypt(credential.refresh_token_encrypted.encode()).decode()
        except (InvalidToken, ValueError, UnicodeError) as exc:
            # A lost/wrong encryption key is an operational failure, not account revocation.
            raise ServiceUnavailableError("Apple credential storage is unavailable") from exc
        try:
            grant = await self.client.refresh_apple_token(provider_token)
            profile = await self.client.verify_apple_identity(
                grant.id_token, access_token=grant.access_token
            )
            if profile.subject != identity.provider_subject:
                raise SocialAuthInvalidCredentialError
        except SocialAuthNotConfiguredError as exc:
            raise ServiceUnavailableError("Apple authentication is not configured") from exc
        except SocialAuthInvalidCredentialError:
            await self._revoke_sessions(user_id, credential, now)
        except (SocialAuthTimeoutError, SocialAuthUpstreamError) as exc:
            # Keep both provider and Clipback credentials intact during an outage.
            raise ExternalServiceError("Apple authentication provider unavailable") from exc
        if grant.refresh_token is not None:
            credential.refresh_token_encrypted = cipher.encrypt(
                grant.refresh_token.encode()
            ).decode()
        credential.last_verified_at = now
        await self.repository.session.flush()

    async def _revoke_sessions(self, user_id: int, credential, now: datetime) -> None:
        if credential is not None:
            credential.revoked_at = now
            credential.refresh_token_encrypted = None
        await self.auth_session_repository.revoke_all_for_user(user_id)
        # The caller returns 401, but this confirmed revocation must survive that error.
        await self.repository.session.commit()
        raise AuthenticationError("Apple authorization was revoked; sign in again")
