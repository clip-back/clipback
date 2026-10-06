from dataclasses import replace
from datetime import UTC, datetime, timedelta
from random import Random

import pytest

from app.core.recommendation_config import RECOMMENDATION_TIMEZONE
from app.schemas.recommendation import TodayCandidate
from app.services.recommendation_selection import calculate_today_score, get_stage, select_today

NOW = datetime(2026, 9, 24, 9, tzinfo=UTC)


def candidate(
    content_id,
    *,
    saved_days=30,
    viewed_days=None,
    open_count=0,
    recommended_days=None,
    favorite=False,
    categories=(),
):
    return TodayCandidate(
        id=content_id,
        saved_at=NOW - timedelta(days=saved_days),
        last_viewed_at=None if viewed_days is None else NOW - timedelta(days=viewed_days),
        open_count=open_count,
        last_recommended_at=(
            None if recommended_days is None else NOW - timedelta(days=recommended_days)
        ),
        is_favorite=favorite,
        category_ids=categories,
    )


class RecordingRandom(Random):
    def __init__(self, seed=17, *, choose_first=False):
        super().__init__(seed)
        self.choose_first = choose_first
        self.pools = []
        self.weights = []
        self.drawn = []

    def shuffle(self, values):
        if not self.choose_first:
            super().shuffle(values)

    def choices(self, population, weights=None, *, cum_weights=None, k=1):
        self.pools.append([entry[0].id for entry in population])
        self.weights.append(list(weights))
        result = (
            [population[0]]
            if self.choose_first
            else super().choices(population, weights, cum_weights=cum_weights, k=k)
        )
        self.drawn.extend(entry[0].id for entry in result)
        return result


@pytest.mark.parametrize("count,stage", [(0, 0), (4, 0), (5, 1), (9, 1), (10, 2), (100, 2)])
def test_stage_uses_current_content_count(count, stage):
    assert get_stage(count) == stage


@pytest.mark.parametrize("count", [0, 1, 4])
def test_stage_zero_does_not_select(count):
    rng = RecordingRandom()
    assert (
        select_today(
            [candidate(i) for i in range(1, count + 1)],
            now=NOW,
            exposed_yesterday=set(),
            rng=rng,
        )
        == []
    )
    assert rng.drawn == []


def test_stage_one_orders_exposure_then_unread_oldest_view_and_newest_save():
    candidates = [
        candidate(1),
        candidate(2, viewed_days=10, open_count=1),
        candidate(3, saved_days=1, viewed_days=20, open_count=1),
        candidate(4, saved_days=1),
        candidate(5, saved_days=2, viewed_days=20, open_count=1),
        candidate(6, saved_days=0),
        candidate(7, saved_days=0.5),
    ]
    original = list(candidates)

    selected = select_today(candidates, now=NOW, exposed_yesterday={6}, rng=Random(17))

    assert [item.content_id for item in selected] == [7, 4, 1, 3, 5]
    assert all(item.score is None for item in selected)
    assert candidates == original


@pytest.mark.parametrize("exposed", [{4, 5, 6, 7}, set(range(1, 8))])
def test_stage_one_reallows_yesterday_only_after_all_fresh_candidates(exposed):
    candidates = [candidate(i, saved_days=i) for i in range(1, 8)]

    selected = select_today(candidates, now=NOW, exposed_yesterday=exposed, rng=Random(17))

    assert [item.content_id for item in selected] == [1, 2, 3, 4, 5]
    assert len({item.content_id for item in selected}) == 5


def test_stage_one_does_not_apply_stage_two_recent_filters_or_category_cap():
    candidates = [
        candidate(i, saved_days=0, viewed_days=0, recommended_days=0, categories=(1,))
        for i in range(1, 6)
    ]

    selected = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=Random(17))

    assert {item.content_id for item in selected} == {1, 2, 3, 4, 5}


def test_stage_one_exact_ties_use_injected_randomness():
    candidates = [candidate(i) for i in range(1, 10)]
    first = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=Random(17))
    repeat = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=Random(17))
    different = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=Random(18))

    assert first == repeat
    assert first != different


@pytest.mark.parametrize(
    "values,expected",
    [
        ({"saved_days": 0}, 0.70),
        ({"saved_days": 30, "viewed_days": 7, "recommended_days": 14, "favorite": True}, 1.0),
        (
            {
                "saved_days": 45,
                "viewed_days": 10,
                "recommended_days": 21,
                "open_count": 100,
                "favorite": True,
            },
            0.865,
        ),
        (
            {
                "saved_days": 15,
                "viewed_days": 3.5,
                "recommended_days": 7,
                "open_count": 2,
                "favorite": True,
            },
            0.55,
        ),
        ({"saved_days": -5, "viewed_days": -3, "recommended_days": -4, "open_count": 4}, 0.015),
    ],
)
def test_score_weighted_terms_caps_fractional_days_and_future_timestamps(values, expected):
    assert calculate_today_score(candidate(1, **values), now=NOW) == pytest.approx(expected)


@pytest.mark.parametrize(
    "count,expected",
    [(0, 0.15), (1, 0.1125), (2, 0.075), (3, 0.0375), (4, 0.015), (5, 0.015), (1000, 0.015)],
)
def test_score_uses_the_fixed_view_count_bands(count, expected):
    item = candidate(1, saved_days=0, viewed_days=0, recommended_days=0, open_count=count)
    assert calculate_today_score(item, now=NOW) == pytest.approx(expected)


@pytest.mark.parametrize(
    "field,hours", [("saved_at", 48), ("last_viewed_at", 24), ("last_recommended_at", 72)]
)
@pytest.mark.parametrize("too_recent", [False, True])
def test_stage_two_exclusion_boundaries_are_elapsed_time(field, hours, too_recent):
    timestamp = (
        NOW - timedelta(hours=hours) + (timedelta(microseconds=1) if too_recent else timedelta())
    )
    candidates = [replace(candidate(1), **{field: timestamp})]
    candidates += [candidate(i) for i in range(2, 7)]
    candidates += [candidate(i, viewed_days=0) for i in range(7, 11)]
    rng = RecordingRandom()

    select_today(candidates, now=NOW, exposed_yesterday=set(), rng=rng)

    assert set(rng.pools[0]) == set(range(2, 7)) | ({1} if not too_recent else set())


def test_stage_two_relaxes_recommendation_before_recent_save():
    candidates = [candidate(i) for i in range(1, 4)]
    candidates += [candidate(i, recommended_days=0) for i in (4, 5)]
    candidates += [candidate(i, saved_days=0) for i in (6, 7)]
    candidates += [candidate(i, viewed_days=0) for i in (8, 9, 10)]

    selected = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=Random(17))

    assert {item.content_id for item in selected} == {1, 2, 3, 4, 5}


def test_stage_two_relaxes_save_but_never_relaxes_recent_view():
    candidates = [candidate(i) for i in range(1, 4)]
    candidates += [candidate(4, recommended_days=0)]
    candidates += [candidate(i, saved_days=0) for i in (5, 6, 7)]
    candidates += [candidate(i, viewed_days=0) for i in (8, 9, 10)]
    rng = RecordingRandom()

    selected = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=rng)

    assert set(rng.pools[0]) == set(range(1, 8))
    assert len(selected) == 5
    assert {item.content_id for item in selected} <= set(range(1, 8))


@pytest.mark.parametrize("available", [0, 1, 3, 4])
def test_stage_two_returns_only_available_unique_contents(available):
    candidates = [candidate(i, saved_days=0) for i in range(1, available + 1)]
    candidates += [candidate(i, viewed_days=0) for i in range(available + 1, 11)]

    selected = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=Random(17))

    assert len(selected) == available
    assert {item.content_id for item in selected} == set(range(1, available + 1))


@pytest.mark.parametrize(
    "count,pool_size",
    [(3, 3), (10, 10), (11, 10), (33, 10), (34, 11), (100, 30), (101, 30), (1000, 30)],
)
def test_stage_two_pool_clamps_to_available_minimum_maximum_and_rounds_up(count, pool_size):
    candidates = [candidate(i) for i in range(1, count + 1)]
    candidates += [candidate(i, viewed_days=0) for i in range(count + 1, 11)]
    rng = RecordingRandom()

    selected = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=rng)

    assert len(rng.pools[0]) == pool_size
    assert len(selected) == min(count, 5)
    assert {item.content_id for item in selected} <= set(rng.pools[0])


def test_stage_two_draws_from_top_scores_with_score_weights_and_preserves_draw_order():
    candidates = [candidate(i, saved_days=2 + i / 2) for i in range(1, 41)]
    original = list(candidates)
    rng = RecordingRandom()

    selected = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=rng)

    assert set(rng.pools[0]) == set(range(29, 41))
    scores = {item.id: calculate_today_score(item, now=NOW) for item in candidates}
    for pool, weights in zip(rng.pools, rng.weights, strict=True):
        assert weights == pytest.approx([scores[content_id] for content_id in pool])
    assert [item.content_id for item in selected] == rng.drawn
    assert len(set(rng.drawn)) == 5
    assert [item.score for item in selected] == pytest.approx([scores[i] for i in rng.drawn])
    assert candidates == original


def test_stage_two_pool_cutoff_ties_are_randomized():
    candidates = [candidate(i) for i in range(1, 41)]
    first_rng, second_rng = RecordingRandom(17), RecordingRandom(18)

    first = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=first_rng)
    repeat = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=RecordingRandom(17))
    select_today(candidates, now=NOW, exposed_yesterday=set(), rng=second_rng)

    assert first == repeat
    assert set(first_rng.pools[0]) != set(second_rng.pools[0])


def test_stage_two_multi_category_item_counts_towards_each_category_cap():
    candidates = [
        candidate(7, categories=(1, 2)),
        candidate(1, categories=(1,)),
        candidate(4, categories=(2,)),
        candidate(2, categories=(1,)),
        candidate(5, categories=(2,)),
        *[candidate(i, categories=(i,)) for i in range(8, 13)],
    ]
    rng = RecordingRandom(choose_first=True)

    selected = select_today(candidates, now=NOW, exposed_yesterday=set(), rng=rng)

    assert [item.content_id for item in selected] == [7, 1, 4, 8, 9]
    assert 2 not in rng.pools[2]
    assert 5 not in rng.pools[3]


def test_stage_two_relaxes_category_cap_within_the_original_top_pool():
    candidates = [
        candidate(i, saved_days=2 + i / 2, categories=(1 if i >= 29 else 2,)) for i in range(1, 41)
    ]

    selected = select_today(
        candidates,
        now=NOW,
        exposed_yesterday=set(),
        rng=RecordingRandom(choose_first=True),
    )

    assert [item.content_id for item in selected] == [40, 39, 38, 37, 36]


def test_time_zone_and_elapsed_comparison_do_not_depend_on_timestamp_offsets():
    candidates = [
        candidate(i, saved_days=2, viewed_days=1, recommended_days=3) for i in range(1, 11)
    ]
    local_candidates = [
        replace(
            item,
            saved_at=item.saved_at.astimezone(RECOMMENDATION_TIMEZONE),
            last_viewed_at=item.last_viewed_at.astimezone(RECOMMENDATION_TIMEZONE),
            last_recommended_at=item.last_recommended_at.astimezone(RECOMMENDATION_TIMEZONE),
        )
        for item in candidates
    ]

    assert NOW.astimezone(RECOMMENDATION_TIMEZONE).utcoffset() == timedelta(hours=9)
    assert select_today(
        candidates, now=NOW, exposed_yesterday=set(), rng=Random(17)
    ) == select_today(
        local_candidates,
        now=NOW.astimezone(RECOMMENDATION_TIMEZONE),
        exposed_yesterday=set(),
        rng=Random(17),
    )
