import pytest

from app.integrations.storage_client import LocalStorageClient


@pytest.mark.asyncio
async def test_local_storage_saves_reads_and_deletes_file(tmp_path) -> None:
    client = LocalStorageClient(tmp_path)

    await client.save_file("screenshots/1/image.png", b"image")

    assert await client.read_file("screenshots/1/image.png") == b"image"
    await client.delete_file("screenshots/1/image.png")
    with pytest.raises(FileNotFoundError):
        await client.read_file("screenshots/1/image.png")


@pytest.mark.asyncio
async def test_local_storage_rejects_path_traversal(tmp_path) -> None:
    client = LocalStorageClient(tmp_path)

    with pytest.raises(ValueError, match="escapes the storage root"):
        await client.save_file("../outside.png", b"image")
