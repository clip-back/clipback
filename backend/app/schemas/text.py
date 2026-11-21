import unicodedata


def contains_unstorable_text(value: str) -> bool:
    # PostgreSQL text cannot store NUL or unpaired surrogates.
    return "\x00" in value or any(unicodedata.category(char) == "Cs" for char in value)


def reject_unstorable_text(value: str | None) -> str | None:
    if value is not None and contains_unstorable_text(value):
        raise ValueError("Text contains unsupported characters")
    return value
