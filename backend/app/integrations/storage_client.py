class StorageClient:
    async def save_file(self, filename: str, content: bytes) -> str:
        return f"local/{filename}"

