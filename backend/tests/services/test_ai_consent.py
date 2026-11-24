"""#474 AI 처리 허용 진리표 × 재동의 규칙, enumerated in full."""

from datetime import UTC, datetime, timedelta

import pytest

from app.services.ai_consent import ConsentRecord, ai_allowed, effective_status, save_allowed

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


# Save requests: a re-grant covers a save only when the save started under that same
# committed decision (#475 review Spec 1). Rows: current record × switch × record the
# save's first check read.
OLD_REGRANT = ConsentRecord("granted", 1, BEFORE, True)
STARTED = {
    "none": None, "denied": RECORDS["denied"], "first_grant": RECORDS["first_grant"],
    "same_regrant": RECORDS["regrant"], "older_regrant": OLD_REGRANT,
}
SAVE_TABLE = {
    (record, switch, started): (
        False if record == "denied"
        else (not switch) if record == "none"
        else True if record == "first_grant"
        else started == "same_regrant"
    )
    for record in RECORDS for switch in (False, True) for started in STARTED
}


@pytest.mark.parametrize(("record", "switch", "started"), sorted(SAVE_TABLE))
def test_save_allowed_table(record, switch, started):
    assert save_allowed(
        RECORDS[record], started_under=STARTED[started], required=switch,
    ) is SAVE_TABLE[(record, switch, started)]


def test_save_table_spot_checks():
    # A re-grant committed while the save was running is a different decision.
    assert SAVE_TABLE[("regrant", False, "denied")] is False
    assert SAVE_TABLE[("regrant", False, "older_regrant")] is False
    assert SAVE_TABLE[("regrant", True, "same_regrant")] is True
    # The first grant keeps no such condition, also for a save started while undecided.
    assert SAVE_TABLE[("first_grant", True, "none")] is True
