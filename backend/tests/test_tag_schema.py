import pytest
from pydantic import ValidationError

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
