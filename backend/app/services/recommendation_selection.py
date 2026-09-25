from collections import Counter
from datetime import datetime, timedelta
from math import ceil
from random import Random

from app.core import recommendation_config as config
from app.models.recommendation import RecommendationCardType
from app.schemas.recommendation import (
    TodayCandidate,
    TodaySelection,
    WeeklyCandidate,
    WeeklySelection,
)


def get_stage(content_count: int) -> int:
    if content_count <= config.STAGE_0_MAX:
        return 0
    if content_count <= config.STAGE_1_MAX:
        return 1
    return 2


def _elapsed_score(timestamp: datetime, now: datetime, max_days: int) -> float:
    elapsed_days = (now - timestamp).total_seconds() / config.SECONDS_PER_DAY
    return min(max(elapsed_days, 0), max_days) / max_days


def calculate_today_score(candidate: TodayCandidate, *, now: datetime) -> float:
    return (
        _elapsed_score(candidate.saved_at, now, config.SAVE_SCORE_MAX_DAYS) * config.WEIGHT_SAVE
        + (
            1.0
            if candidate.last_viewed_at is None
            else _elapsed_score(candidate.last_viewed_at, now, config.VIEW_SCORE_MAX_DAYS)
        )
        * config.WEIGHT_LAST_VIEW
        + config.VIEW_COUNT_SCORES[min(candidate.open_count, len(config.VIEW_COUNT_SCORES) - 1)]
        * config.WEIGHT_VIEW_COUNT
        + (
            1.0
            if candidate.last_recommended_at is None
            else _elapsed_score(candidate.last_recommended_at, now, config.RECOMMEND_SCORE_MAX_DAYS)
        )
        * config.WEIGHT_RECENCY
        + int(candidate.is_favorite) * config.WEIGHT_FAVORITE
    )


def select_today(
    candidates: list[TodayCandidate],
    *,
    now: datetime,
    exposed_yesterday: set[int],
    rng: Random,
) -> list[TodaySelection]:
    stage = get_stage(len(candidates))
    if stage == 0:
        return []
    if stage == 1:
        ordered = list(candidates)
        rng.shuffle(ordered)
        ordered.sort(
            key=lambda candidate: (
                candidate.id in exposed_yesterday,
                candidate.last_viewed_at is not None,
                candidate.last_viewed_at.timestamp() if candidate.last_viewed_at else 0,
                -candidate.saved_at.timestamp(),
            )
        )
        return [
            TodaySelection(content_id=candidate.id, score=None)
            for candidate in ordered[: config.TODAY_ITEM_COUNT]
        ]

    view_cutoff = now - timedelta(hours=config.VIEW_EXCLUDE_HOURS)
    save_cutoff = now - timedelta(hours=config.SAVE_EXCLUDE_HOURS)
    recommendation_cutoff = now - timedelta(days=config.RECOMMEND_EXCLUDE_DAYS)
    unviewed_recently = [
        candidate
        for candidate in candidates
        if candidate.last_viewed_at is None or candidate.last_viewed_at <= view_cutoff
    ]
    old_saves = [candidate for candidate in unviewed_recently if candidate.saved_at <= save_cutoff]
    eligible = [
        candidate
        for candidate in old_saves
        if candidate.last_recommended_at is None
        or candidate.last_recommended_at <= recommendation_cutoff
    ]
    if len(eligible) < config.TODAY_ITEM_COUNT:
        eligible = old_saves
    if len(eligible) < config.TODAY_ITEM_COUNT:
        eligible = unviewed_recently

    scored = [(candidate, calculate_today_score(candidate, now=now)) for candidate in eligible]
    rng.shuffle(scored)
    scored.sort(key=lambda entry: entry[1], reverse=True)
    pool_size = min(
        len(scored),
        config.CANDIDATE_MAX,
        max(config.CANDIDATE_MIN, ceil(len(scored) * config.CANDIDATE_TOP_RATIO)),
    )
    remaining = scored[:pool_size]
    category_counts: Counter[int] = Counter()
    selected = []
    while remaining and len(selected) < config.TODAY_ITEM_COUNT:
        allowed = [
            entry
            for entry in remaining
            if all(
                category_counts[category_id] < config.MAX_SAME_CATEGORY
                for category_id in entry[0].category_ids
            )
        ]
        choices = allowed or remaining
        chosen = rng.choices(choices, weights=[score for _, score in choices], k=1)[0]
        remaining.remove(chosen)
        candidate, score = chosen
        category_counts.update(set(candidate.category_ids))
        selected.append(TodaySelection(content_id=candidate.id, score=score))
    return selected


def select_weekly(candidates: list[WeeklyCandidate], *, rng: Random) -> list[WeeklySelection]:
    remaining = list(candidates)
    selected = []
    rankings = (
        (
            RecommendationCardType.MOST_SAVED,
            lambda candidate: (
                candidate.saved_count,
                candidate.last_saved_event_at,
                candidate.category.content_count,
            ),
        ),
        (
            RecommendationCardType.MOST_VIEWED,
            lambda candidate: (
                candidate.viewed_count,
                candidate.last_viewed_event_at,
                candidate.category.content_count,
            ),
        ),
    )
    for card_type, rank in rankings:
        active = [candidate for candidate in remaining if rank(candidate)[0] > 0]
        if not active:
            continue
        highest = max(rank(candidate) for candidate in active)
        tied = [candidate for candidate in active if rank(candidate) == highest]
        chosen = rng.choice(tied) if len(tied) > 1 else tied[0]
        selected.append(WeeklySelection(category_id=chosen.category.id, card_type=card_type))
        remaining.remove(chosen)

    while remaining and len(selected) < config.WEEKLY_ITEM_COUNT:
        tied = [candidate for candidate in remaining if candidate.last_exposed_at is None]
        if not tied:
            oldest = min(candidate.last_exposed_at for candidate in remaining)
            tied = [candidate for candidate in remaining if candidate.last_exposed_at == oldest]
        chosen = rng.choice(tied) if len(tied) > 1 else tied[0]
        selected.append(WeeklySelection(
            category_id=chosen.category.id, card_type=RecommendationCardType.REDISCOVERY
        ))
        remaining.remove(chosen)
    return selected
