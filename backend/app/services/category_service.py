from app.schemas.category import CategoryCreate, CategoryRead


class CategoryService:
    def list_default_categories(self) -> list[CategoryRead]:
        return [
            CategoryRead(id=1, name="취업", color="#4F46E5", is_default=True),
            CategoryRead(id=2, name="공부", color="#059669", is_default=True),
            CategoryRead(id=3, name="업무 팁", color="#DC2626", is_default=True),
            CategoryRead(id=4, name="생활 꿀팁", color="#D97706", is_default=True),
            CategoryRead(id=5, name="장소", color="#0891B2", is_default=True),
            CategoryRead(id=6, name="제품 추천", color="#7C3AED", is_default=True),
        ]

    def create_placeholder(self, payload: CategoryCreate) -> CategoryRead:
        return CategoryRead(id=999, name=payload.name, color=payload.color, is_default=False)

