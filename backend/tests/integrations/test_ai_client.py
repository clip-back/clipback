from types import SimpleNamespace

import pytest

from app.core.config import Settings
from app.integrations import ai_client as ai_client_module
from app.integrations.ai_client import (
    AIClient,
    AIClientError,
    AIClientInvalidResponseError,
    CategorySuggestion,
)


class FakeResponses:
    def __init__(self, response=None, error: Exception | None = None) -> None:
        self.response = response
        self.error = error
        self.kwargs: dict[str, object] | None = None

    async def parse(self, **kwargs):
        self.kwargs = kwargs
        if self.error is not None:
            raise self.error
        return self.response


class FakeOpenAI:
    def __init__(self, responses: FakeResponses) -> None:
        self.responses = responses
        self.closed = False

    async def close(self) -> None:
        self.closed = True


def config() -> Settings:
    return Settings(
        app_environment="test",
        openai_api_key="test-key",
        ai_timeout_seconds=2,
        ai_max_output_tokens=64,
        _env_file=None,
    )


def test_sdk_client_disables_retries_and_uses_two_second_timeout(monkeypatch) -> None:
    captured: dict[str, object] = {}

    def build_client(**kwargs):
        captured.update(kwargs)
        return FakeOpenAI(FakeResponses())

    monkeypatch.setattr(ai_client_module, "AsyncOpenAI", build_client)

    AIClient(config())

    assert captured["api_key"] == "test-key"
    assert captured["timeout"] == 2
    assert captured["max_retries"] == 0


@pytest.mark.asyncio
async def test_structured_response_request_uses_fixed_operational_options() -> None:
    response = SimpleNamespace(
        status="completed",
        output=[],
        output_parsed=CategorySuggestion(category_id=3),
    )
    responses = FakeResponses(response=response)
    openai_client = FakeOpenAI(responses)
    client = AIClient(config(), client=openai_client)

    result = await client.suggest_category_id(
        title="공부 방법",
        description="시험 대비",
        source="web",
        url="https://example.com/post",
        shared_text=None,
        candidates=[(3, "공부")],
    )

    assert result == 3
    assert responses.kwargs is not None
    assert responses.kwargs["model"] == "gpt-5.4-nano-2026-03-17"
    assert responses.kwargs["text_format"] is CategorySuggestion
    assert responses.kwargs["reasoning"] == {"effort": "none"}
    assert responses.kwargs["max_output_tokens"] == 64
    assert responses.kwargs["store"] is False
    assert '"category_id": 3' in responses.kwargs["input"][1]["content"]
    assert '"name": "공부"' in responses.kwargs["input"][1]["content"]

    await client.close()
    assert openai_client.closed is True


@pytest.mark.asyncio
async def test_refusal_is_invalid_response() -> None:
    response = SimpleNamespace(
        status="completed",
        output=[
            SimpleNamespace(
                type="message",
                content=[SimpleNamespace(type="refusal", refusal="no")],
            )
        ],
        output_parsed=None,
    )
    client = AIClient(config(), client=FakeOpenAI(FakeResponses(response=response)))

    with pytest.raises(AIClientInvalidResponseError):
        await client.suggest_category_id(
            title="제목",
            description=None,
            source="web",
            url=None,
            shared_text=None,
            candidates=[(1, "공부")],
        )


@pytest.mark.asyncio
async def test_unparsed_response_is_invalid() -> None:
    response = SimpleNamespace(status="completed", output=[], output_parsed={"category_id": 1})
    client = AIClient(config(), client=FakeOpenAI(FakeResponses(response=response)))

    with pytest.raises(AIClientInvalidResponseError):
        await client.suggest_category_id(
            title="제목",
            description=None,
            source="web",
            url=None,
            shared_text=None,
            candidates=[(1, "공부")],
        )


@pytest.mark.asyncio
async def test_missing_key_uses_fallback_error_without_network_call() -> None:
    client = AIClient(Settings(app_environment="test", openai_api_key=None, _env_file=None))

    with pytest.raises(AIClientError):
        await client.suggest_category_id(
            title="제목",
            description=None,
            source="web",
            url=None,
            shared_text=None,
            candidates=[(1, "공부")],
        )
