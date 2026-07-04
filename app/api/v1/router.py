from fastapi import APIRouter

from app.api.v1.endpoints import auth, categories, contents, feed, health, metrics, uploads, users

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(contents.router, prefix="/contents", tags=["contents"])
api_router.include_router(categories.router, prefix="/categories", tags=["categories"])
api_router.include_router(uploads.router, prefix="/uploads", tags=["uploads"])
api_router.include_router(feed.router, prefix="/feed", tags=["feed"])
api_router.include_router(metrics.router, prefix="/metrics", tags=["metrics"])

