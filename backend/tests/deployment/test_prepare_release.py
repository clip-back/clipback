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
