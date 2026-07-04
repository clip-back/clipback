class AIClient:
    async def summarize(self, text: str) -> str:
        return text[:280]

    async def suggest_tags(self, text: str) -> list[str]:
        return []

