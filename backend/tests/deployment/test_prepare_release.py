"""Release preparation is verified through its CLI and generated operator record."""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parents[2]
TEMPLATE = BACKEND.parent / 'docs/releases/TEMPLATE.md'


def git(repo, *args):
    return subprocess.run(['git', '-C', str(repo), *args], check=True,
                          capture_output=True, text=True).stdout.strip()


@pytest.fixture
def release_repo(tmp_path):
    repo = tmp_path / 'project'
    repo.mkdir()
    git(repo, 'init')
    git(repo, 'config', 'user.email', 'tests@example.invalid')
    git(repo, 'config', 'user.name', 'Release Tests')
    releases = repo / 'docs/releases'
    releases.mkdir(parents=True)
    shutil.copy(TEMPLATE, releases / 'TEMPLATE.md')
    (repo / 'app-version.txt').write_text('0.1.0+1\n')
    git(repo, 'add', '.')
    git(repo, 'commit', '-m', 'initial fixture')
    remote = tmp_path / 'origin.git'
    subprocess.run(['git', 'init', '--bare', str(remote)], check=True, capture_output=True)
    git(repo, 'remote', 'add', 'origin', str(remote))
    return repo


def prepare(repo, *extra):
    return subprocess.run([
        sys.executable, '-m', 'scripts.prepare_release', 'backend', '--repo', str(repo),
        '--id', 'backend-2026-10-27-1', '--source', 'HEAD',
        '--change', '선택한 서버 수정', *extra,
    ], cwd=BACKEND, env={**os.environ, 'PYTHONPATH': str(BACKEND)},
        capture_output=True, text=True)


def test_backend_record_links_full_source_and_keeps_deployment_unknown(release_repo):
    repo = release_repo
    before = git(repo, 'rev-parse', 'HEAD')
    result = prepare(repo, '--environment', 'staging', '--api-version', '/api/v1')
    assert result.returncode == 0, result.stderr + result.stdout
    output = json.loads(result.stdout)
    assert output['created'] is True
    assert output['source_sha'] == before
    assert output['checks']['remote_tags'] == 'checked'
    assert output['deployment_verified'] is False
    record = (repo / 'docs/releases/backend-2026-10-27-1.md').read_text()
    assert '# backend-2026-10-27-1' in record
    assert before in record
    assert '선택한 서버 수정' in record
    assert '| 실제 앱 버전 | 해당 없음 | 해당 없음 |' in record
    assert '| iOS Simulator | 해당 없음 | 해당 없음 | 해당 없음 |' in record
    assert '| Android Emulator | 해당 없음 | 해당 없음 | 해당 없음 |' in record
    assert '| API 계약 버전 | /api/v1 |' in record
    assert '| 배포 환경 | staging |' in record
    assert '| 실제 서버 배포 상태·시각·근거 | 미확인 |' in record
    assert 'backend-2026-10-27-1 (미생성)' in record
    assert '준비일:' in record and 'KST' in record
    assert git(repo, 'tag', '--list') == ''
    assert git(repo, 'rev-parse', 'HEAD') == before
    assert (repo / 'app-version.txt').read_text() == '0.1.0+1\n'
    assert result.stderr == ''


@pytest.mark.parametrize('identifier', [
    'backend-2026-02-30-1', 'backend-2026-10-27-0', 'backend-2026-10-27-01',
    '../unexpected', 'backend-2026-1-2-1',
])
def test_bad_server_identifier_fails_without_creating_a_record(release_repo, identifier):
    result = prepare(release_repo, '--id', identifier)
    assert result.returncode == 1
    assert json.loads(result.stdout)['error'] == 'invalid_backend_identifier'
    assert sorted(p.name for p in (release_repo / 'docs/releases').iterdir()) == ['TEMPLATE.md']


@pytest.mark.parametrize('extra', [
    ['--change', ''], ['--change', 'line\nbreak'], ['--environment', 'line\nbreak'],
    ['--source', 'missing-source'], ['--source=--all'],
])
def test_invalid_inputs_fail_without_partial_record_or_raw_errors(release_repo, extra):
    result = prepare(release_repo, *extra)
    assert result.returncode == 1
    assert json.loads(result.stdout)['created'] is False
    assert result.stderr == ''
    assert sorted(p.name for p in (release_repo / 'docs/releases').iterdir()) == ['TEMPLATE.md']


@pytest.mark.parametrize('location', ['local', 'remote'])
def test_existing_candidate_tag_is_rejected_and_preserved(release_repo, location):
    repo = release_repo
    identifier = 'backend-2026-10-27-1'
    git(repo, 'tag', identifier)
    if location == 'remote':
        git(repo, 'push', 'origin', 'refs/tags/' + identifier)
        git(repo, 'tag', '-d', identifier)
    before_tags = git(repo, 'tag', '--list')
    result = prepare(repo)
    assert result.returncode == 1
    assert json.loads(result.stdout)['error'] == 'tag_conflict'
    assert result.stderr == ''
    assert not (repo / f'docs/releases/{identifier}.md').exists()
    assert git(repo, 'tag', '--list') == before_tags


def test_unavailable_remote_creates_only_an_explicitly_unverified_draft(release_repo):
    repo = release_repo
    git(repo, 'remote', 'set-url', 'origin', '/nonexistent/private-provider-details')
    result = prepare(repo)
    assert result.returncode == 0
    output = json.loads(result.stdout)
    assert output['checks']['remote_tags'] == 'unknown'
    assert output['identifier_checks_complete'] is False
    record = (repo / 'docs/releases/backend-2026-10-27-1.md').read_text()
    assert 'remote_tags_unavailable' in record
    assert '미확인 사유: 초안; 산출물·운영 반영 미확인; remote_tags_unavailable' in record
    assert '미확인' in record
    assert 'private-provider-details' not in record + result.stdout + result.stderr
    assert result.stderr == ''


def test_retry_never_overwrites_existing_history(release_repo):
    repo = release_repo
    path = repo / 'docs/releases/backend-2026-10-27-1.md'
    path.write_text('이전 배포 실패와 롤백 기록\n')
    result = prepare(repo)
    assert result.returncode == 1
    assert json.loads(result.stdout)['error'] == 'record_exists'
    assert path.read_text() == '이전 배포 실패와 롤백 기록\n'


def test_current_template_is_used_and_bad_template_leaves_no_partial_record(release_repo):
    repo = release_repo
    template = repo / 'docs/releases/TEMPLATE.md'
    template.write_text(template.read_text() + '\n## 담당자 수동 확인\n\n추가된 확인란\n')
    first = prepare(repo)
    assert first.returncode == 0
    record = repo / 'docs/releases/backend-2026-10-27-1.md'
    assert '## 담당자 수동 확인' in record.read_text()
    template.write_text('배포 개요가 없는 잘못된 양식')
    result = prepare(repo, '--id', 'backend-2026-10-27-2')
    assert result.returncode == 1
    assert not (repo / 'docs/releases/backend-2026-10-27-2.md').exists()
    assert '추가된 확인란' in record.read_text()


def prepare_app(repo, *extra):
    return subprocess.run([
        sys.executable, '-m', 'scripts.prepare_release', 'app', '--repo', str(repo),
        '--version', '0.2.0', '--ios-build', '21', '--ios-source', 'HEAD',
        '--change', '선택한 앱 개선', *extra,
    ], cwd=BACKEND, env={**os.environ, 'PYTHONPATH': str(BACKEND)},
        capture_output=True, text=True)


def test_ios_candidate_records_source_without_inventing_upload_history(release_repo):
    repo = release_repo
    before = git(repo, 'rev-parse', 'HEAD')
    result = prepare_app(repo)
    assert result.returncode == 0, result.stdout + result.stderr
    output = json.loads(result.stdout)
    assert output['source_shas'] == {'ios': before}
    assert output['checks']['ios_store_history'] == 'unknown'
    assert output['identifier_checks_complete'] is False
    assert output['deployment_verified'] is False
    record = (repo / 'docs/releases/app-v0.2.0-ios-b21.md').read_text()
    assert '| 실제 앱 버전 | 0.2.0 | 해당 없음 |' in record
    assert '| 실제 빌드 번호 | 21 | 해당 없음 |' in record
    assert f'| 빌드 소스 SHA | {before} | 해당 없음 |' in record
    assert 'app-ios-v0.2.0-b21 (미생성)' in record
    assert 'ios_store_history_unavailable' in record
    assert '| 업로드·처리 상태 | 미확인 | 해당 없음 |' in record
    assert '| 실제 공개일·시각 | 미확인 | 해당 없음 |' in record
    assert '선택한 앱 개선' in record
    assert git(repo, 'tag', '--list') == ''
    assert git(repo, 'rev-parse', 'HEAD') == before
    assert (repo / 'app-version.txt').read_text() == '0.1.0+1\n'
    assert result.stderr == ''


@pytest.mark.parametrize('extra', [
    ['--version', '../escape'], ['--version', '01.2.0'], ['--version', '1.2'],
    ['--ios-build', '0'], ['--ios-build', '01'], ['--ios-build', '-1'],
    ['--ios-source', 'missing-source'], ['--ios-source=--all'],
    ['--android-build', '8'], ['--android-source', 'HEAD'],
    ['--change', ''], ['--remote', 'origin\nprivate'],
])
def test_invalid_app_inputs_do_not_write_any_candidate(release_repo, extra):
    result = prepare_app(release_repo, *extra)
    assert result.returncode == 1
    assert json.loads(result.stdout)['created'] is False
    assert result.stderr == ''
    assert sorted(p.name for p in (release_repo / 'docs/releases').iterdir()) == ['TEMPLATE.md']


def test_app_requires_at_least_one_complete_platform(release_repo):
    result = subprocess.run([
        sys.executable, '-m', 'scripts.prepare_release', 'app', '--repo', str(release_repo),
        '--version', '0.2.0', '--change', '앱 변경',
    ], cwd=BACKEND, capture_output=True, text=True)
    assert result.returncode == 1
    assert json.loads(result.stdout)['error'] == 'platform_required'
    assert not (release_repo / 'docs/releases/app-v0.2.0.md').exists()


@pytest.mark.parametrize('location', ['candidate', 'legacy', 'local_tag', 'remote_tag'])
def test_reserved_build_under_another_version_is_not_reused(release_repo, location):
    repo = release_repo
    old_record = repo / 'docs/releases/app-v0.1.0-ios-b21-android-b8.md'
    if location == 'candidate':
        old_record.write_text('실패한 후보와 롤백 기록\n')
    elif location == 'legacy':
        old_record = repo / 'docs/releases/app-v0.1.0.md'
        old_record.write_text('| 항목 | iOS | Android |\n| 실제 빌드 번호 | 21 | 8 |\n')
    else:
        git(repo, 'tag', 'app-ios-v0.1.0-b21')
        if location == 'remote_tag':
            git(repo, 'push', 'origin', 'refs/tags/app-ios-v0.1.0-b21')
            git(repo, 'tag', '-d', 'app-ios-v0.1.0-b21')
    result = prepare_app(repo)
    assert result.returncode == 1
    assert json.loads(result.stdout)['error'] == 'build_conflict'
    assert not (repo / 'docs/releases/app-v0.2.0-ios-b21.md').exists()
    if old_record.exists():
        assert '21' in old_record.name or '21' in old_record.read_text()


def test_new_build_same_version_preserves_old_candidate_and_overview(release_repo):
    repo = release_repo
    first = prepare_app(repo)
    assert first.returncode == 0
    old = repo / 'docs/releases/app-v0.2.0-ios-b21.md'
    old.write_text(old.read_text() + '\n이전 실패·롤백 기록\n')
    before = old.read_bytes()
    overview = repo / 'docs/releases/app-v0.2.0.md'
    overview.write_text('수동 개요와 최종 선택한 후보\n')
    assert prepare_app(repo).returncode == 1
    second = prepare_app(repo, '--ios-build', '22')
    assert second.returncode == 0, second.stdout
    assert (repo / 'docs/releases/app-v0.2.0-ios-b22.md').exists()
    assert old.read_bytes() == before
    assert overview.read_text() == '수동 개요와 최종 선택한 후보\n'


def store_history(repo, **values):
    path = repo / 'store-history.json'
    path.write_text(json.dumps({
        'platform': 'ios', 'source': 'App Store Connect: clipback test app',
        'checked_at': '2026-10-27T09:00:00+09:00', 'highest_build': 20, **values,
    }))
    return str(path)


def test_manual_upload_snapshot_is_recorded_and_blocks_older_builds(release_repo):
    repo = release_repo
    evidence = store_history(repo)
    blocked = prepare_app(repo, '--ios-build', '20', '--ios-store-history', evidence)
    assert blocked.returncode == 1
    assert json.loads(blocked.stdout)['error'] == 'build_conflict'
    assert not (repo / 'docs/releases/app-v0.2.0-ios-b20.md').exists()
    result = prepare_app(repo, '--ios-store-history', evidence)
    assert result.returncode == 0, result.stderr + result.stdout
    output = json.loads(result.stdout)
    assert output['checks']['ios_store_history'] == 'manual_snapshot'
    assert output['identifier_checks_complete'] is True
    record = (repo / 'docs/releases/app-v0.2.0-ios-b21.md').read_text()
    assert 'App Store Connect: clipback test app' in record
    assert '2026-10-27T09:00:00+09:00' in record
    assert '수동 확인값: 최대 업로드 빌드 20' in record
    assert '| 업로드·처리 상태 | 미확인 | 해당 없음 |' in record


@pytest.mark.parametrize('values', [
    {'highest_build': -1}, {'highest_build': True}, {'highest_build': '20'},
    {'source': ''}, {'checked_at': '2026-10-27'}, {'platform': 'android'},
])
def test_malformed_upload_snapshot_fails_without_partial_record(release_repo, values):
    evidence = store_history(release_repo, **values)
    result = prepare_app(release_repo, '--ios-store-history', evidence)
    assert result.returncode == 1
    assert json.loads(result.stdout)['error'] == 'invalid_store_history'
    assert result.stderr == ''
    assert not (release_repo / 'docs/releases/app-v0.2.0-ios-b21.md').exists()


def test_unreadable_upload_snapshot_stays_unknown_without_leaking_path(release_repo):
    result = prepare_app(release_repo, '--ios-store-history', '/missing/private-evidence')
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)['checks']['ios_store_history'] == 'unknown'
    assert json.loads(result.stdout)['identifier_checks_complete'] is False
    record = (release_repo / 'docs/releases/app-v0.2.0-ios-b21.md').read_text()
    assert 'private-evidence' not in record + result.stdout + result.stderr


def test_platform_sources_and_combined_server_are_recorded_independently(release_repo):
    repo = release_repo
    ios_sha = git(repo, 'rev-parse', 'HEAD')
    (repo / 'android-change.txt').write_text('Android only')
    git(repo, 'add', 'android-change.txt')
    git(repo, 'commit', '-m', 'android fixture')
    android_sha = git(repo, 'rev-parse', 'HEAD')
    result = prepare_app(repo, '--ios-source', ios_sha,
                         '--android-build', '8', '--android-source', android_sha,
                         '--server-source', ios_sha, '--environment', 'staging',
                         '--api-version', '/api/v1')
    assert result.returncode == 0, result.stderr + result.stdout
    assert json.loads(result.stdout)['source_shas'] == {'ios': ios_sha, 'android': android_sha}
    record = (repo / 'docs/releases/app-v0.2.0-ios-b21-android-b8.md').read_text()
    assert f'| 빌드 소스 SHA | {ios_sha} | {android_sha} |' in record
    assert '| 실제 빌드 번호 | 21 | 8 |' in record
    assert '| 업로드·처리 상태 | 미확인 | 미확인 |' in record
    assert '| 실제 공개일·시각 | 미확인 | 미확인 |' in record
    assert f'| 서버 소스 SHA·산출물 식별자 | {ios_sha} / 산출물 미확인 |' in record
    assert '| API 계약 버전 | /api/v1 |' in record
    assert '| 실제 서버 배포 상태·시각·근거 | 미확인 |' in record


def test_android_only_has_no_ios_or_server_completion_claim(release_repo):
    repo = release_repo
    result = subprocess.run([
        sys.executable, '-m', 'scripts.prepare_release', 'app', '--repo', str(repo),
        '--version', '0.2.0', '--android-build', '8', '--android-source', 'HEAD',
        '--change', 'Android 개선',
    ], cwd=BACKEND, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr + result.stdout
    record = (repo / 'docs/releases/app-v0.2.0-android-b8.md').read_text()
    assert '| 실제 앱 버전 | 해당 없음 | 0.2.0 |' in record
    assert '| 실제 빌드 번호 | 해당 없음 | 8 |' in record
    assert '| 실제 공개일·시각 | 해당 없음 | 미확인 |' in record
    assert '| iOS Simulator | 해당 없음 | 해당 없음 | 해당 없음 |' in record
    assert '| 서버 배포 대상 여부 | 미확인 |' in record


@pytest.mark.parametrize('location', ['local', 'remote'])
def test_app_exact_tag_collision_is_rejected(release_repo, location):
    repo = release_repo
    git(repo, 'tag', 'app-ios-v0.2.0-b21')
    if location == 'remote':
        git(repo, 'push', 'origin', 'refs/tags/app-ios-v0.2.0-b21')
        git(repo, 'tag', '-d', 'app-ios-v0.2.0-b21')
    result = prepare_app(repo)
    assert result.returncode == 1
    assert json.loads(result.stdout)['error'] == 'tag_conflict'
    assert not (repo / 'docs/releases/app-v0.2.0-ios-b21.md').exists()


def test_unknown_app_remote_does_not_override_manual_store_evidence(release_repo):
    repo = release_repo
    evidence = store_history(repo)
    git(repo, 'remote', 'set-url', 'origin', '/missing/private-provider')
    result = prepare_app(repo, '--ios-store-history', evidence)
    assert result.returncode == 0
    output = json.loads(result.stdout)
    assert output['checks']['ios_remote_tags'] == 'unknown'
    assert output['checks']['ios_store_history'] == 'manual_snapshot'
    assert output['identifier_checks_complete'] is False
    record = (repo / 'docs/releases/app-v0.2.0-ios-b21.md').read_text()
    assert 'ios_remote_tags_unavailable' in record
    assert 'private-provider' not in record + result.stdout + result.stderr
