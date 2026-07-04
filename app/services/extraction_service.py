from app.integrations.ai_client import AIClient
from app.integrations.metadata_client import MetadataClient
from app.integrations.ocr_client import OCRClient


class ExtractionService:
    def __init__(
        self,
        metadata_client: MetadataClient | None = None,
        ai_client: AIClient | None = None,
        ocr_client: OCRClient | None = None,
    ) -> None:
        self.metadata_client = metadata_client or MetadataClient()
        self.ai_client = ai_client or AIClient()
        self.ocr_client = ocr_client or OCRClient()

