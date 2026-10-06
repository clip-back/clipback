from copy import deepcopy
from datetime import UTC, datetime, timedelta
from random import Random

import pytest

from app.models.recommendation import RecommendationCardType
from app.schemas.category import CategorySummaryRead
from app.schemas.recommendation import WeeklyCandidate
from app.services.recommendation_selection import select_weekly

NOW = datetime(2026, 9, 25, 9, tzinfo=UTC)


def candidate(
    category_id,
    *,
    saved=0,
    viewed=0,
    saved_hours=1,
    viewed_hours=1,
    current_count=1,
    exposed_hours=None,
):
    return WeeklyCandidate(
        category=CategorySummaryRead(
            id=category_id,
            name=f"Category {category_id}",
            color=None,
            is_default=False,
            content_count=current_count,
            last_saved_at=NOW - timedelta(days=1),
        ),
        saved_count=saved,
        last_saved_event_at=NOW - timedelta(hours=saved_hours) if saved else None,
        viewed_count=viewed,
        last_viewed_event_at=NOW - timedelta(hours=viewed_hours) if viewed else None,
        last_exposed_at=(
            NOW - timedelta(hours=exposed_hours) if exposed_hours is not None else None
        ),
    )


class RecordingRandom(Random):
    def __init__(self, seed=17):
        super().__init__(seed)
        self.pools = []

    def choice(self, population):
        self.pools.append([item.category.id for item in population])
        return super().choice(population)


def cards(selected):
    return [(item.category_id, item.card_type.value) for item in selected]


@pytest.mark.parametrize("count", [0, 1, 2, 3, 8])
def test_returns_at_most_two_distinct_categories_without_input_changes(count):
    candidates = [candidate(index) for index in range(1, count + 1)]
    before = deepcopy(candidates)

    selected = select_weekly(candidates, rng=Random(17))

    assert len(selected) == min(count, 2)
    assert len({item.category_id for item in selected}) == len(selected)
    assert all(item.card_type == RecommendationCardType.REDISCOVERY for item in selected)
    assert candidates == before


@pytest.mark.parametrize(
    "saved,viewed,expected",
    [
        (0, 0, "REDISCOVERY"),
        (1, 0, "MOST_SAVED"),
        (0, 1, "MOST_VIEWED"),
        (1, 1, "MOST_SAVED"),
    ],
)
def test_one_category_uses_its_actual_activity_once(saved, viewed, expected):
    rng = RecordingRandom()

    selected = select_weekly([candidate(1, saved=saved, viewed=viewed)], rng=rng)

    assert cards(selected) == [(1, expected)]
    assert rng.pools == []


@pytest.mark.parametrize(
    "candidates,expected",
    [
        (
            [candidate(1, saved=3), candidate(2, viewed=4)],
            [(1, "MOST_SAVED"), (2, "MOST_VIEWED")],
        ),
        (
            [candidate(1, saved=3, viewed=4), candidate(2, viewed=2)],
            [(1, "MOST_SAVED"), (2, "MOST_VIEWED")],
        ),
        (
            [candidate(1, saved=3, viewed=4), candidate(2)],
            [(1, "MOST_SAVED"), (2, "REDISCOVERY")],
        ),
        (
            [candidate(1, saved=3), candidate(2, saved=1)],
            [(1, "MOST_SAVED"), (2, "REDISCOVERY")],
        ),
        (
            [candidate(1), candidate(2, viewed=4)],
            [(2, "MOST_VIEWED"), (1, "REDISCOVERY")],
        ),
    ],
)
def test_activity_cards_are_chosen_before_fallback_and_keep_return_order(candidates, expected):
    before = deepcopy(candidates)

    assert cards(select_weekly(candidates, rng=Random(17))) == expected
    assert candidates == before


@pytest.mark.parametrize("activity", ["saved", "viewed"])
@pytest.mark.parametrize("tie_break", ["count", "recent_event", "current_count"])
def test_activity_ranking_uses_count_then_event_time_then_current_count(activity, tie_break):
    timestamp_field = f"{activity}_hours"
    options = {
        "count": [
            {activity: 3, timestamp_field: 10, "current_count": 1},
            {activity: 2, timestamp_field: 1, "current_count": 100},
        ],
        "recent_event": [
            {activity: 3, timestamp_field: 1, "current_count": 1},
            {activity: 3, timestamp_field: 10, "current_count": 100},
        ],
        "current_count": [
            {activity: 3, timestamp_field: 1, "current_count": 2},
            {activity: 3, timestamp_field: 1, "current_count": 1},
        ],
    }[tie_break]
    candidates = [candidate(index, **values) for index, values in enumerate(options, 1)]
    rng = RecordingRandom()

    selected = select_weekly(candidates, rng=rng)

    assert selected[0].category_id == 1
    expected_type = "MOST_SAVED" if activity == "saved" else "MOST_VIEWED"
    assert selected[0].card_type.value == expected_type
    assert rng.pools == []


@pytest.mark.parametrize("activity", ["saved", "viewed"])
def test_activity_randomness_only_receives_exact_top_ties(activity):
    candidates = [candidate(1, **{activity: 4}), candidate(2, **{activity: 4})]
    candidates += [candidate(3, **{activity: 3}, current_count=100)]
    rng = RecordingRandom()

    selected = select_weekly(candidates, rng=rng)

    assert rng.pools[0] == [1, 2]
    assert selected[0].category_id in {1, 2}
    assert len({item.category_id for item in selected}) == 2


def test_viewed_rank_excludes_saved_winner_before_breaking_ties():
    candidates = [
        candidate(1, saved=10, viewed=10),
        candidate(2, viewed=5, viewed_hours=1),
        candidate(3, viewed=5, viewed_hours=2),
    ]
    rng = RecordingRandom()

    assert cards(select_weekly(candidates, rng=rng)) == [
        (1, "MOST_SAVED"), (2, "MOST_VIEWED")
    ]
    assert rng.pools == []


def test_fallback_cannot_take_the_only_viewed_category():
    candidates = [
        candidate(1, exposed_hours=1),
        candidate(2, viewed=1),
        candidate(3, exposed_hours=2),
    ]

    assert cards(select_weekly(candidates, rng=Random(17))) == [
        (2, "MOST_VIEWED"), (3, "REDISCOVERY")
    ]


def test_rediscovery_prefers_all_unexposed_candidates_with_equal_chance():
    candidates = [
        candidate(1, current_count=100, exposed_hours=100),
        candidate(2, current_count=1),
        candidate(3, current_count=100),
    ]
    rng = RecordingRandom()

    selected = select_weekly(candidates, rng=rng)

    assert {item.category_id for item in selected} == {2, 3}
    assert rng.pools == [[2, 3]]
    assert all(item.card_type == RecommendationCardType.REDISCOVERY for item in selected)


def test_rediscovery_uses_oldest_last_exposure_after_unexposed_candidates():
    candidates = [
        candidate(1, exposed_hours=1),
        candidate(2, exposed_hours=100),
        candidate(3),
    ]
    rng = RecordingRandom()

    assert cards(select_weekly(candidates, rng=rng)) == [
        (3, "REDISCOVERY"), (2, "REDISCOVERY")
    ]
    assert rng.pools == []


def test_rediscovery_uses_each_category_latest_exposure_then_chooses_oldest():
    candidates = [
        candidate(1, exposed_hours=1),
        candidate(2, exposed_hours=10),
        candidate(3, exposed_hours=5),
    ]
    rng = RecordingRandom()

    assert cards(select_weekly(candidates, rng=rng)) == [
        (2, "REDISCOVERY"), (3, "REDISCOVERY")
    ]
    assert rng.pools == []


def test_rediscovery_randomness_only_receives_the_oldest_exposure_ties():
    candidates = [candidate(1, exposed_hours=1)]
    candidates += [candidate(index, exposed_hours=10) for index in (2, 3, 4)]
    rng = RecordingRandom()

    selected = select_weekly(candidates, rng=rng)

    assert set(rng.pools[0]) == {2, 3, 4}
    assert set(rng.pools[1]) == {2, 3, 4} - {selected[0].category_id}
    assert {item.category_id for item in selected} <= {2, 3, 4}


@pytest.mark.parametrize("activity", [None, "saved", "viewed"])
def test_injected_seed_is_repeatable_and_different_seeds_can_change_exact_ties(activity):
    counts = {activity: 1} if activity else {}
    candidates = [candidate(index, **counts) for index in range(1, 9)]

    first = select_weekly(candidates, rng=Random(17))
    repeat = select_weekly(candidates, rng=Random(17))
    different = select_weekly(candidates, rng=Random(18))

    assert first == repeat
    assert first != different
