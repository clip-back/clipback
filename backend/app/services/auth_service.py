from datetime import UTC, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError

from app.core.config import settings
from app.core.exceptions import (
    AuthenticationError,
    ExternalServiceError,
    InvalidStateError,
    ServiceUnavailableError,
    SystemConfigurationError,
)
from app.core.security import create_access_token, generate_refresh_token, hash_refresh_token
from app.integrations.social_auth_client import (
    SocialAuthClient,
    SocialAuthInvalidCredentialError,
    SocialAuthNotConfiguredError,
    SocialAuthTimeoutError,
    SocialAuthUpstreamError,
    SocialProfile,
)
from app.models.social_identity import SocialProvider
from app.repositories.auth_session_repository import AuthSessionRepository
from app.repositories.social_identity_repository import SocialIdentityRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import AppleTokenRequest, SocialTokenResponse, TokenResponse
from app.services.apple_auth_service import AppleAuthService, VerifiedAppleLogin


class AuthService:
    def __init__(
        self,
        *,
        user_repository: UserRepository,
        auth_session_repository: AuthSessionRepository,
        social_identity_repository: SocialIdentityRepository,
        social_auth_client: SocialAuthClient,
        apple_auth_service: AppleAuthService | None = None,
    ) -> None:
        self.user_repository = user_repository
        self.auth_session_repository = auth_session_repository
        self.social_identity_repository = social_identity_repository
        self.social_auth_client = social_auth_client
        self.apple_auth_service = apple_auth_service

    async def create_guest_session(self) -> TokenResponse:
        refresh_token = generate_refresh_token()
        now = datetime.now(UTC)

        try:
            user = await self.user_repository.create_guest()
            auth_session = await self.auth_session_repository.create(
                user_id=user.id,
                refresh_token_hash=hash_refresh_token(refresh_token),
                expires_at=now + timedelta(days=settings.refresh_token_expire_days),
            )
            response = self._build_token_response(
                user_id=user.id,
                session_id=auth_session.id,
                refresh_token=refresh_token,
            )
            await self.auth_session_repository.session.commit()
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

        return response

    async def refresh_session(self, refresh_token: str) -> TokenResponse:
        now = datetime.now(UTC)
        if self.apple_auth_service is not None:
            await self.apple_auth_service.lock_user_for_refresh(hash_refresh_token(refresh_token))
        auth_session = await self.auth_session_repository.get_by_refresh_token_hash_for_update(
            hash_refresh_token(refresh_token)
        )
        if (
            auth_session is None
            or auth_session.revoked_at is not None
            or auth_session.expires_at <= now
        ):
            await self.auth_session_repository.session.rollback()
            raise AuthenticationError("Invalid or expired refresh token")

        user = await self.user_repository.get(auth_session.user_id)
        if user is None:
            await self.auth_session_repository.session.rollback()
            raise AuthenticationError("Invalid or expired refresh token")

        new_refresh_token = generate_refresh_token()
        try:
            if self.apple_auth_service is not None:
                await self.apple_auth_service.validate_refresh(user.id)
            await self.auth_session_repository.rotate(
                auth_session,
                refresh_token_hash=hash_refresh_token(new_refresh_token),
                expires_at=now + timedelta(days=settings.refresh_token_expire_days),
            )
            response = self._build_token_response(
                user_id=user.id,
                session_id=auth_session.id,
                refresh_token=new_refresh_token,
            )
            await self.auth_session_repository.session.commit()
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

        return response

    async def logout(self, refresh_token: str) -> None:
        auth_session = await self.auth_session_repository.get_by_refresh_token_hash_for_update(
            hash_refresh_token(refresh_token)
        )
        if auth_session is None:
            await self.auth_session_repository.session.rollback()
            return

        try:
            await self.auth_session_repository.revoke(auth_session)
            await self.auth_session_repository.session.commit()
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

    async def social_login(
        self,
        *,
        provider: SocialProvider,
        token: str,
    ) -> SocialTokenResponse:
        profile = await self._verify_social_token(provider=provider, token=token)
        return await self._login_with_profile(profile)

    async def apple_login(self, payload: AppleTokenRequest) -> SocialTokenResponse:
        if self.apple_auth_service is None:
            raise ServiceUnavailableError("Apple authentication is not configured")
        login = await self.apple_auth_service.authenticate(payload, purpose="login")
        return await self._login_with_profile(login.profile, apple_login=login)

    async def _login_with_profile(
        self, profile: SocialProfile, *, apple_login: VerifiedAppleLogin | None = None
    ) -> SocialTokenResponse:
        creating_identity = False

        try:
            identity = await self.social_identity_repository.get_by_provider_subject(
                provider=profile.provider,
                provider_subject=profile.subject,
            )
            if identity is None:
                creating_identity = True
                user = await self.user_repository.create_social(
                    email=profile.email,
                    display_name=profile.display_name,
                )
                identity = await self.social_identity_repository.create(
                    user_id=user.id,
                    provider=profile.provider,
                    provider_subject=profile.subject,
                )
            else:
                user = await (
                    self.user_repository.get_for_update(identity.user_id)
                    if apple_login else self.user_repository.get(identity.user_id)
                )
                if user is None:
                    raise AuthenticationError()

            if apple_login is not None:
                await self.apple_auth_service.save_login(identity, apple_login)
            response = await self._create_social_token_response(
                user_id=user.id,
                is_new_user=creating_identity,
            )
            await self.auth_session_repository.session.commit()
            return response
        except IntegrityError as exc:
            await self.auth_session_repository.session.rollback()
            if not creating_identity:
                raise
            return await self._complete_concurrent_social_login(
                profile=profile, error=exc, apple_login=apple_login
            )
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

    async def upgrade_guest_with_social(
        self,
        *,
        user_id: int,
        provider: SocialProvider,
        token: str,
    ) -> SocialTokenResponse:
        profile = await self._verify_social_token(provider=provider, token=token)
        return await self._upgrade_guest_with_profile(user_id=user_id, profile=profile)

    async def upgrade_guest_with_apple(
        self, *, user_id: int, payload: AppleTokenRequest
    ) -> SocialTokenResponse:
        if self.apple_auth_service is None:
            raise ServiceUnavailableError("Apple authentication is not configured")
        login = await self.apple_auth_service.authenticate(
            payload, purpose="upgrade", user_id=user_id
        )
        return await self._upgrade_guest_with_profile(
            user_id=user_id, profile=login.profile, apple_login=login
        )

    async def _upgrade_guest_with_profile(
        self, *, user_id: int, profile: SocialProfile,
        apple_login: VerifiedAppleLogin | None = None,
    ) -> SocialTokenResponse:

        try:
            user = await self.user_repository.get_for_update(user_id)
            if user is None:
                raise AuthenticationError()
            if not user.is_guest:
                raise InvalidStateError("Only guest users can be upgraded")

            existing_identity = await self.social_identity_repository.get_by_provider_subject(
                provider=profile.provider,
                provider_subject=profile.subject,
            )
            # Upgrade is the only linking operation. An account can acquire one provider only.
            linked_providers = await self.social_identity_repository.list_providers(user.id)
            if existing_identity is not None or linked_providers:
                raise InvalidStateError("Social account is already linked")

            await self.user_repository.promote_guest(
                user,
                email=profile.email,
                display_name=profile.display_name,
            )
            identity = await self.social_identity_repository.create(
                user_id=user.id,
                provider=profile.provider,
                provider_subject=profile.subject,
            )
            if apple_login is not None:
                await self.apple_auth_service.save_login(identity, apple_login)
            await self.auth_session_repository.revoke_all_for_user(user.id)
            response = await self._create_social_token_response(
                user_id=user.id,
                is_new_user=False,
            )
            await self.auth_session_repository.session.commit()
            return response
        except IntegrityError as exc:
            await self.auth_session_repository.session.rollback()
            raise InvalidStateError("Social account is already linked") from exc
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

    async def _complete_concurrent_social_login(
        self,
        *,
        profile: SocialProfile,
        error: IntegrityError,
        apple_login: VerifiedAppleLogin | None = None,
    ) -> SocialTokenResponse:
        try:
            identity = await self.social_identity_repository.get_by_provider_subject(
                provider=profile.provider,
                provider_subject=profile.subject,
            )
            if identity is None:
                raise error
            user = await (
                self.user_repository.get_for_update(identity.user_id)
                if apple_login else self.user_repository.get(identity.user_id)
            )
            if user is None:
                raise error
            if apple_login is not None:
                await self.apple_auth_service.save_login(identity, apple_login)
            response = await self._create_social_token_response(
                user_id=user.id,
                is_new_user=False,
            )
            await self.auth_session_repository.session.commit()
            return response
        except Exception:
            await self.auth_session_repository.session.rollback()
            raise

    async def _create_social_token_response(
        self,
        *,
        user_id: int,
        is_new_user: bool,
    ) -> SocialTokenResponse:
        refresh_token = generate_refresh_token()
        auth_session = await self.auth_session_repository.create(
            user_id=user_id,
            refresh_token_hash=hash_refresh_token(refresh_token),
            expires_at=datetime.now(UTC) + timedelta(days=settings.refresh_token_expire_days),
        )
        token_response = self._build_token_response(
            user_id=user_id,
            session_id=auth_session.id,
            refresh_token=refresh_token,
        )
        return SocialTokenResponse(
            **token_response.model_dump(),
            is_new_user=is_new_user,
        )

    async def _verify_social_token(
        self,
        *,
        provider: SocialProvider,
        token: str,
    ) -> SocialProfile:
        if provider not in {SocialProvider.GOOGLE, SocialProvider.KAKAO}:
            raise HTTPException(422, "Unsupported social provider")
        try:
            return await self.social_auth_client.verify(provider=provider, token=token)
        except SocialAuthNotConfiguredError as exc:
            raise SystemConfigurationError("Social authentication is not configured") from exc
        except SocialAuthInvalidCredentialError as exc:
            raise AuthenticationError("Invalid social authentication credential") from exc
        except (SocialAuthTimeoutError, SocialAuthUpstreamError) as exc:
            raise ExternalServiceError("Social authentication provider unavailable") from exc

    @staticmethod
    def _build_token_response(
        *,
        user_id: int,
        session_id: int,
        refresh_token: str,
    ) -> TokenResponse:
        return TokenResponse(
            access_token=create_access_token(user_id=user_id, session_id=session_id),
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.access_token_expire_minutes * 60,
            refresh_expires_in=settings.refresh_token_expire_days * 24 * 60 * 60,
        )
