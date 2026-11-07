import pytest

from tests.deployment.restore_evidence import FAILURE


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(item, call):
    # Fixtures run teardown after this report, so they can tell whether the test body failed.
    report = yield
    if report.when == "call" and report.failed and call.excinfo is not None:
        item.stash[FAILURE] = call.excinfo.value
    return report
