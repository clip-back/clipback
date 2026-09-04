from app.repositories.content_repository import ContentRepository


def test_build_search_pattern_escapes_like_wildcards() -> None:
    pattern = ContentRepository._build_search_pattern("Path\\100%_DONE")

    assert pattern == "%Path\\\\100\\%\\_DONE%"
