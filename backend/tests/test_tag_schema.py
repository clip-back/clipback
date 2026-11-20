import pytest
from pydantic import ValidationError

from app.schemas import tag
from app.schemas.content import ContentCreate


def test_tag_names_are_normalized_and_deduplicated() -> None:
    payload = ContentCreate(
        tag_names=["  Ｆｌｕｔｔｅｒ  ", "#flutter", "백   엔드", "C#"],
    )

    assert payload.tag_names == ["Flutter", "백 엔드", "C#"]


@pytest.mark.parametrize(
    "tag_names",
    [
        [""],
        ["#"],
        ["x" * 41],
        [str(index) for index in range(11)],
    ],
)
def test_tag_names_reject_invalid_values(tag_names: list[str]) -> None:
    with pytest.raises(ValidationError):
        ContentCreate(tag_names=tag_names)


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("  성수동\t카페 ", "성수동 카페"),
        ("요리\n레시피", "요리 레시피"),
        ("\u3000캠핑\u3000", "캠핑"),
        ("＃요리", "요리"),
        ("# # 요리", "요리"),
        ("#C#", "C#"),
        ("C#", "C#"),
        ("ＡＢＣ", "ABC"),
        ("１２３", "123"),
        ("ß" * 20, "ß" * 20),
        ("요\u200b리", "요리"),
        ("#\u200b요리", "요리"),
        ("👩\u200d🍳\ufeff\u2060\u200e\u00ad", "👩🍳"),
        ("요리 \u200b\t레시피", "요리 레시피"),
    ],
)
def test_normalize_tag_name_character_range(value: str, expected: str) -> None:
    assert tag.normalize_tag_name(value) == expected


@pytest.mark.parametrize(
    ("value", "message"),
    [
        pytest.param("#", "cannot be blank", id="hash-only"),
        pytest.param(" \t\n", "cannot be blank", id="whitespace-only"),
        pytest.param("ß" * 21, "cannot exceed 40", id="casefold-expansion"),
        pytest.param("ﬁ" * 21, "cannot exceed 40", id="nfkc-expansion"),
        pytest.param("\u200b", "cannot be blank", id="format-only"),
    ],
)
def test_normalize_tag_name_rejects_blank_or_long_names(value: str, message: str) -> None:
    with pytest.raises(ValueError, match=message):
        tag.normalize_tag_name(value)


@pytest.mark.parametrize(
    ("response", "expected"),
    [
        pytest.param(
            {"tags": ["요리", "요리", "레시피", "김치"]},
            ["요리", "레시피", "김치"],
            id="deduplicate-before-limit",
        ),
        pytest.param(
            {"tags": ["#", "가" * 41, "a", "b", "c"]}, ["a", "b", "c"],
            id="validate-before-limit",
        ),
        pytest.param({"tags": ["Python", "python", "x"]}, ["Python", "x"], id="first-case"),
        pytest.param(
            {"tags": ["python", "Python", "x"]}, ["python", "x"], id="first-case-reversed",
        ),
        pytest.param({"tags": ["요리", 5, None, "김치"]}, ["요리", "김치"], id="mixed-list"),
        pytest.param(
            {"tags": ["요리", ["nested"], {"name": "김치"}, "김치"]}, ["요리", "김치"],
            id="nested-nonstrings",
        ),
        pytest.param({"tags": ["\u200b", "요리"]}, ["요리"], id="format-only-item"),
        pytest.param(
            {"tags": ["\ud83d", "\ud83d요리", "김치"]}, ["김치"], id="unpaired-surrogates",
        ),
        pytest.param({"tags": ["\x00", "요\x00리", "김치"]}, ["김치"], id="nul-items"),
        pytest.param({"tags": ["# Ｐython", "py\u200bthon"]}, ["Python"], id="normalize-first"),
        pytest.param({"tags": ["a", "b", "c", "d"]}, ["a", "b", "c"], id="limit-to-three"),
        pytest.param({"tags": "요리"}, [], id="string-field"),
        pytest.param({"tags": 5}, [], id="number-field"),
        pytest.param({"tags": {"name": "요리"}}, [], id="object-field"),
        pytest.param({"tags": None}, [], id="null-field"),
        pytest.param({}, [], id="missing-field"),
        pytest.param({"tags": []}, [], id="empty-list"),
        pytest.param({"tags": [None, "#", "ß" * 21]}, [], id="no-valid-items"),
    ],
)
def test_clean_ai_tag_names(response: dict[str, object], expected: list[str]) -> None:
    assert tag.clean_ai_tag_names(response.get("tags")) == expected
