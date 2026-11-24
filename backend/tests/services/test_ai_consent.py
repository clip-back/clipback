"""#474 AI 처리 허용 진리표 × 재동의 규칙, enumerated in full."""

from datetime import UTC, datetime, timedelta

import pytest

from app.services.ai_consent import ConsentRecord, ai_allowed, effective_status

DECIDED = datetime(2026, 11, 25, 3, tzinfo=UTC)
BEFORE, SAME, AFTER = DECIDED - timedelta(microseconds=1), DECIDED, DECIDED + timedelta(hours=1)

RECORDS = {
    "none": None,
    "denied": ConsentRecord("denied", 1, DECIDED, False),
    "first_grant": ConsentRecord("granted", 1, DECIDED, False),
    "regrant": ConsentRecord("granted", 1, DECIDED, True),
}
STATUS = {"none": "undecided", "denied": "denied", "first_grant": "granted", "regrant": "granted"}

# (record, switch on, data time) -> allowed. Every combination is listed.
TABLE = {
    ("none", False, "before"): True, ("none", False, "same"): True,
    ("none", False, "after"): True,
    ("none", True, "before"): False, ("none", True, "same"): False,
    ("none", True, "after"): False,
    ("denied", False, "before"): False, ("denied", False, "same"): False,
    ("denied", False, "after"): False,
    ("denied", True, "before"): False, ("denied", True, "same"): False,
    ("denied", True, "after"): False,
    ("first_grant", False, "before"): True, ("first_grant", False, "same"): True,
    ("first_grant", False, "after"): True,
    ("first_grant", True, "before"): True, ("first_grant", True, "same"): True,
    ("first_grant", True, "after"): True,
    ("regrant", False, "before"): False, ("regrant", False, "same"): True,
    ("regrant", False, "after"): True,
    ("regrant", True, "before"): False, ("regrant", True, "same"): True,
    ("regrant", True, "after"): True,
}
TIMES = {"before": BEFORE, "same": SAME, "after": AFTER}


def test_table_covers_every_combination():
    assert set(TABLE) == {
        (record, switch, time)
        for record in RECORDS for switch in (False, True) for time in TIMES
    }


@pytest.mark.parametrize(("record", "switch", "time"), sorted(TABLE))
def test_ai_allowed_truth_table(record, switch, time):
    assert ai_allowed(
        RECORDS[record], required=switch, data_at=TIMES[time],
    ) is TABLE[(record, switch, time)]


@pytest.mark.parametrize("record", sorted(RECORDS))
def test_effective_status(record):
    assert effective_status(RECORDS[record]) == STATUS[record]
