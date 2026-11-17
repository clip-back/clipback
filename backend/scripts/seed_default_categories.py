DEFAULT_CATEGORIES = [
    {"name": "취업", "color": "#64B5F6"},
    {"name": "공부", "color": "#5BD89D"},
    {"name": "업무 팁", "color": "#FF6277"},
    {"name": "생활 꿀팁", "color": "#FFA24B"},
    {"name": "장소", "color": "#FFD75C"},
    {"name": "제품 추천", "color": "#B9AAFF"},
    {"name": "미분류", "color": "#6B7280"},
]


def main() -> None:
    for category in DEFAULT_CATEGORIES:
        print(f"{category['name']} {category['color']}")


if __name__ == "__main__":
    main()
