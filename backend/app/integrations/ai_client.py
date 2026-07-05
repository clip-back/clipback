class AIClient:
    async def summarize(self, text: str) -> str:
        return text[:280]

    async def suggest_category_ids(self, text: str, candidate_category_ids: list[int]) -> list[int]:
        return []
