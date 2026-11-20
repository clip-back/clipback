from typing import Annotated

from pydantic import WithJsonSchema

# The SDK sends the array schema but accepts malformed tag values in responses.
AIResponseTags = Annotated[
    object, WithJsonSchema({"type": "array", "items": {"type": "string"}})
]

TAG_PROMPT = (
    " Return tags as up to three short Korean words describing what the content is about. "
    "Keep proper nouns in their original language and omit the # prefix. "
    "Use hashtags in Instagram captions only as evidence and do not copy them as tags. "
    "Return fewer tags or an empty list when evidence is limited."
)
