DEFAULT_CATEGORIES = [
    {"name": "취업", "color": "#4F46E5"},
    {"name": "공부", "color": "#059669"},
    {"name": "업무 팁", "color": "#DC2626"},
    {"name": "생활 꿀팁", "color": "#D97706"},
    {"name": "장소", "color": "#0891B2"},
    {"name": "제품 추천", "color": "#7C3AED"},
    {"name": "미분류", "color": "#6B7280"},
]


def main() -> None:
    for category in DEFAULT_CATEGORIES:
        print(f"{category['name']} {category['color']}")


if __name__ == "__main__":
    main()
