from fastapi import HTTPException, status


class NotFoundError(HTTPException):
    def __init__(self, detail: str = "Resource not found") -> None:
        super().__init__(status_code=status.HTTP_404_NOT_FOUND, detail=detail)


class InvalidStateError(HTTPException):
    def __init__(self, detail: str = "Invalid resource state") -> None:
        super().__init__(status_code=status.HTTP_409_CONFLICT, detail=detail)


class AuthenticationError(HTTPException):
    def __init__(self, detail: str = "Invalid authentication credentials") -> None:
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"},
        )


class SystemConfigurationError(HTTPException):
    def __init__(self, detail: str = "System configuration error") -> None:
        super().__init__(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=detail)
