"""Prepare a release record without tagging, building, uploading or deploying."""

import argparse
import json
import re
import subprocess
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

KST = timezone(timedelta(hours=9))


class PreparationError(ValueError):
    pass


def single_line(value):
    if not value.strip() or any(ord(character) < 32 for character in value):
        raise PreparationError('invalid_text_input')
    return value.replace('|', '&#124;')


def backend_identifier(value):
    match = re.fullmatch(r'backend-(\d{4}-\d{2}-\d{2})-([1-9]\d*)', value)
    try:
        if not match:
            raise ValueError
        date.fromisoformat(match[1])
    except ValueError:
        raise PreparationError('invalid_backend_identifier') from None
    return value


def git(repo, *args):
    return subprocess.run(['git', '-C', str(repo), *args], check=True,
                          capture_output=True, text=True, timeout=20).stdout.strip()


def check_tags(repo, tag, remote):
    if tag in git(repo, 'tag', '--list').splitlines():
        raise PreparationError('tag_conflict')
    try:
        rows = git(repo, 'ls-remote', '--tags', '--refs', '--', remote, f'refs/tags/{tag}')
    except (OSError, subprocess.SubprocessError):
        return 'unknown'
    if rows:
        raise PreparationError('tag_conflict')
    return 'checked'


def render_record(template, identifier, source_sha, changes, args, checked_at, remote_status):
    record = f'# {identifier}\n\n' + template[template.index('## 배포 개요'):]
    record = record.replace('- 배포 식별자: 미확인', f'- 배포 식별자: {identifier}')
    record = record.replace('- 준비일: 미확인', f'- 준비일: {checked_at}')
    record = record.replace('의 항목 또는 앵커: 미확인',
                            '의 항목 또는 앵커: ' + '; '.join(changes))
    note = '초안; 산출물·운영 반영 미확인'
    if remote_status == 'unknown':
        note += '; remote_tags_unavailable'
    record = record.replace('- 후보 준비 상태·미확인 사유: 미확인',
                            f'- 후보 준비 상태·미확인 사유: {note}')
    record = record.replace('| 기존 후보 기록·로컬 태그 | 미확인 | 미확인 |',
                            '| 기존 후보 기록·로컬 태그 | '
                            f'로컬 저장소 / {checked_at} | 충돌 없음 |')
    status = ('동일 태그 없음' if remote_status == 'checked'
              else '미확인: remote_tags_unavailable')
    record = record.replace('| 원격 태그 | 미확인 | 미확인 |',
                            f'| 원격 태그 | {args.remote} / {checked_at} | {status} |')
    for platform in ('iOS', 'Android'):
        record = record.replace(f'| {platform} 업로드 이력 | 미확인 | 미확인 |',
                                f'| {platform} 업로드 이력 | 해당 없음 | 해당 없음 |')
    for platform in ('iOS Simulator', 'Android Emulator'):
        record = record.replace(f'| {platform} | 미확인 | 미확인 | 미확인 |',
                                f'| {platform} | 해당 없음 | 해당 없음 | 해당 없음 |')
    for label, value in {
        '서버 배포 대상 여부': '대상',
        '서버 소스 SHA·산출물 식별자': f'{source_sha} / 산출물 미확인',
        '서버 후보 태그·실제 생성 여부': f'{identifier} (미생성)',
        '배포 환경': args.environment or '미확인',
        'API 계약 버전': args.api_version or '미확인',
    }.items():
        record = record.replace(f'| {label} | 미확인 |', f'| {label} | {value} |')
    start = record.index('## 모바일 플랫폼별 기록')
    end = record.index('## 서버와 마이그레이션')
    record = record[:start] + record[start:end].replace('| 미확인 | 미확인 |',
                                                       '| 해당 없음 | 해당 없음 |') + record[end:]
    return record


def prepare_backend(args):
    backend_identifier(args.id)
    args.change = [single_line(value) for value in args.change]
    args.environment = single_line(args.environment) if args.environment is not None else None
    args.api_version = single_line(args.api_version) if args.api_version is not None else None
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/-]*', args.remote):
        raise PreparationError('invalid_remote_name')
    repo = Path(args.repo).resolve()
    destination = repo / 'docs/releases' / f'{args.id}.md'
    if destination.exists() or destination.is_symlink():
        raise PreparationError('record_exists')
    source_sha = git(repo, 'rev-parse', '--verify', '--end-of-options',
                     args.source + '^{commit}')
    remote_status = check_tags(repo, args.id, args.remote)
    checked_at = datetime.now(KST).isoformat(timespec='seconds') + ' KST'
    template = (repo / 'docs/releases/TEMPLATE.md').read_text(encoding='utf-8')
    record = render_record(template, args.id, source_sha, args.change, args, checked_at,
                           remote_status)
    with destination.open('x', encoding='utf-8') as handle:
        handle.write(record)
    return {'created': True, 'record': str(destination), 'source_sha': source_sha,
            'checks': {'local_records_and_tags': 'checked', 'remote_tags': remote_status},
            'identifier_checks_complete': remote_status == 'checked',
            'deployment_verified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    backend = sub.add_parser('backend')
    backend.add_argument('--repo', default=str(Path(__file__).resolve().parents[2]))
    backend.add_argument('--id', required=True)
    backend.add_argument('--source', required=True)
    backend.add_argument('--change', action='append', required=True)
    backend.add_argument('--environment')
    backend.add_argument('--api-version')
    backend.add_argument('--remote', default='origin')
    args = parser.parse_args()
    try:
        print(json.dumps(prepare_backend(args), ensure_ascii=False, sort_keys=True))
        return 0
    except PreparationError as exc:
        print(json.dumps({'created': False, 'error': str(exc)}))
        return 1
    except FileExistsError:
        print(json.dumps({'created': False, 'error': 'record_exists'}))
        return 1
    except (OSError, subprocess.SubprocessError, ValueError):
        print(json.dumps({'created': False, 'error': 'release_preparation_failed'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
