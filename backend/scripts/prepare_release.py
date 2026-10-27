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


def record_overview(template, identifier, changes, checked_at, note):
    record = f'# {identifier}\n\n' + template[template.index('## 배포 개요'):]
    record = record.replace('- 배포 식별자: 미확인', f'- 배포 식별자: {identifier}')
    record = record.replace('- 준비일: 미확인', f'- 준비일: {checked_at}')
    record = record.replace('의 항목 또는 앵커: 미확인',
                            '의 항목 또는 앵커: ' + '; '.join(changes))
    record = record.replace('- 후보 준비 상태·미확인 사유: 미확인',
                            f'- 후보 준비 상태·미확인 사유: {note}')
    record = record.replace('| 기존 후보 기록·로컬 태그 | 미확인 | 미확인 |',
                            '| 기존 후보 기록·로컬 태그 | '
                            f'로컬 저장소 / {checked_at} | 충돌 없음 |')
    return record


def render_record(template, identifier, source_sha, changes, args, checked_at, remote_status):
    note = '초안; 산출물·운영 반영 미확인'
    if remote_status == 'unknown':
        note += '; remote_tags_unavailable'
    record = record_overview(template, identifier, changes, checked_at, note)
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


def check_app_build(repo, platform, build, tag, remote):
    highest = 0
    column = 1 if platform == 'ios' else 2
    for path in (repo / 'docs/releases').glob('app-v*.md'):
        for reserved_platform, number in re.findall(r'-(ios|android)-b([1-9][0-9]*)', path.stem):
            if reserved_platform == platform:
                highest = max(highest, int(number))
        for line in path.read_text(encoding='utf-8').splitlines():
            cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
            if len(cells) == 3 and cells[0] == '실제 빌드 번호' and cells[column].isdigit():
                highest = max(highest, int(cells[column]))
    local_tags = git(repo, 'tag', '--list').splitlines()
    if tag in local_tags:
        raise PreparationError('tag_conflict')
    status = 'checked'
    try:
        remote_rows = git(repo, 'ls-remote', '--tags', '--refs', '--', remote,
                          f'refs/tags/app-{platform}-v*-b*')
        remote_tags = [row.split('\t')[-1].removeprefix('refs/tags/')
                       for row in remote_rows.splitlines()]
    except (OSError, subprocess.SubprocessError):
        remote_tags, status = [], 'unknown'
    if tag in remote_tags:
        raise PreparationError('tag_conflict')
    for name in local_tags + remote_tags:
        match = re.fullmatch(rf'app-{platform}-v[0-9]+\.[0-9]+\.[0-9]+-b([1-9][0-9]*)', name)
        if match:
            highest = max(highest, int(match[1]))
    if int(build) <= highest:
        raise PreparationError('build_conflict')
    return status


def upload_history(path, platform, build):
    if path is None:
        return None
    try:
        raw = Path(path).read_text(encoding='utf-8')
    except OSError:
        return None
    try:
        data = json.loads(raw)
        if not isinstance(data, dict) or data.get('platform') != platform:
            raise ValueError
        if type(data.get('highest_build')) is not int or data['highest_build'] < 0:
            raise ValueError
        if not isinstance(data.get('source'), str) or not isinstance(data.get('checked_at'), str):
            raise ValueError
        data['source'] = single_line(data['source'])
        checked = datetime.fromisoformat(data['checked_at'])
        if checked.tzinfo is None:
            raise ValueError
    except ValueError:
        raise PreparationError('invalid_store_history') from None
    if int(build) <= data['highest_build']:
        raise PreparationError('build_conflict')
    data['checked_at'] = checked.astimezone(KST).isoformat(timespec='seconds') + ' KST'
    return data


def prepare_app(args):
    if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', args.version):
        raise PreparationError('invalid_app_version')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/-]*', args.remote):
        raise PreparationError('invalid_remote_name')
    repo = Path(args.repo).resolve()
    changes = [single_line(value) for value in args.change]
    platforms = {}
    for platform in ('ios', 'android'):
        build = getattr(args, platform + '_build')
        source = getattr(args, platform + '_source')
        if (build is None) != (source is None):
            raise PreparationError('platform_build_and_source_required')
        if build is None and getattr(args, platform + '_store_history') is not None:
            raise PreparationError('platform_build_and_source_required')
        if build is not None:
            if not re.fullmatch(r'[1-9][0-9]*', build):
                raise PreparationError('invalid_build_number')
            platforms[platform] = {
                'build': build,
                'source': git(repo, 'rev-parse', '--verify', '--end-of-options',
                              source + '^{commit}'),
                'tag': f'app-{platform}-v{args.version}-b{build}',
                'history': upload_history(getattr(args, platform + '_store_history'),
                                          platform, build),
            }
    if not platforms:
        raise PreparationError('platform_required')
    server_sha = (git(repo, 'rev-parse', '--verify', '--end-of-options',
                      args.server_source + '^{commit}') if args.server_source else None)
    environment = single_line(args.environment) if args.environment is not None else '미확인'
    api_version = single_line(args.api_version) if args.api_version is not None else '미확인'
    identifier = f'app-v{args.version}' + ''.join(
        f'-{platform}-b{data["build"]}' for platform, data in platforms.items())
    destination = repo / 'docs/releases' / f'{identifier}.md'
    if destination.exists() or destination.is_symlink():
        raise PreparationError('record_exists')
    remote_status = {
        platform: check_app_build(repo, platform, data['build'], data['tag'], args.remote)
        for platform, data in platforms.items()
    }
    checked_at = datetime.now(KST).isoformat(timespec='seconds') + ' KST'
    template = (repo / 'docs/releases/TEMPLATE.md').read_text(encoding='utf-8')
    reasons = [platform + '_store_history_unavailable'
               for platform, data in platforms.items() if data['history'] is None]
    reasons += [platform + '_remote_tags_unavailable'
                for platform, status in remote_status.items() if status == 'unknown']
    note = '초안; 산출물·공개 미확인; ' + '; '.join(reasons)
    record = record_overview(template, identifier, changes, checked_at, note)
    remote_text = '; '.join(f'{platform}: {status}' for platform, status in remote_status.items())
    record = record.replace('| 원격 태그 | 미확인 | 미확인 |',
                            f'| 원격 태그 | {args.remote} / {checked_at} | {remote_text} |')
    for platform, title in (('ios', 'iOS'), ('android', 'Android')):
        data = platforms.get(platform)
        evidence, status = '해당 없음', '해당 없음'
        if data:
            history = data['history']
            evidence = f'{history["source"]} / {history["checked_at"]}' if history else '미확인'
            status = (f'수동 확인값: 최대 업로드 빌드 {history["highest_build"]}' if history
                      else f'미확인: {platform}_store_history_unavailable')
        record = record.replace(f'| {title} 업로드 이력 | 미확인 | 미확인 |',
                                f'| {title} 업로드 이력 | {evidence} | {status} |')
        if data is None:
            scenario = 'iOS Simulator' if platform == 'ios' else 'Android Emulator'
            record = record.replace(f'| {scenario} | 미확인 | 미확인 | 미확인 |',
                                    f'| {scenario} | 해당 없음 | 해당 없음 | 해당 없음 |')
    for label, value in {
        '서버 배포 대상 여부': '대상' if server_sha else '미확인',
        '서버 소스 SHA·산출물 식별자': f'{server_sha} / 산출물 미확인' if server_sha else '미확인',
        '배포 환경': environment,
        'API 계약 버전': api_version,
    }.items():
        record = record.replace(f'| {label} | 미확인 |', f'| {label} | {value} |')
    rows = {}
    for label in ('배포 대상 여부', '실제 앱 버전', '실제 빌드 번호', '빌드 소스 SHA',
                  '후보 태그·실제 생성 여부'):
        values = []
        for platform in ('ios', 'android'):
            data = platforms.get(platform)
            values.append('해당 없음' if data is None else {
                '배포 대상 여부': '대상', '실제 앱 버전': args.version,
                '실제 빌드 번호': data['build'], '빌드 소스 SHA': data['source'],
                '후보 태그·실제 생성 여부': data['tag'] + ' (미생성)',
            }[label])
        rows[label] = values
    start, end = record.index('## 모바일 플랫폼별 기록'), record.index('## 서버와 마이그레이션')
    mobile = record[start:end]
    for label, values in rows.items():
        mobile = mobile.replace(f'| {label} | 미확인 | 미확인 |',
                                f'| {label} | {values[0]} | {values[1]} |')
    for index, platform in enumerate(('ios', 'android')):
        if platform not in platforms:
            mobile = '\n'.join(
                re.sub(r'^\| (.+) \| (.+) \| 미확인 \|$', r'| \1 | \2 | 해당 없음 |', line)
                if index == 1 else re.sub(
                    r'^\| (.+) \| 미확인 \| (.+) \|$', r'| \1 | 해당 없음 | \2 |', line)
                for line in mobile.split('\n'))
    record = record[:start] + mobile + record[end:]
    with destination.open('x', encoding='utf-8') as handle:
        handle.write(record)
    return {'created': True, 'record': str(destination),
            'source_shas': {key: data['source'] for key, data in platforms.items()},
            'checks': {**{key + '_remote_tags': value for key, value in remote_status.items()},
                       **{key + '_store_history': (
                           'manual_snapshot' if data['history'] else 'unknown')
                          for key, data in platforms.items()}},
            'identifier_checks_complete': not reasons, 'deployment_verified': False}


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
    app = sub.add_parser('app')
    app.add_argument('--repo', default=str(Path(__file__).resolve().parents[2]))
    app.add_argument('--version', required=True)
    app.add_argument('--change', action='append', required=True)
    app.add_argument('--remote', default='origin')
    app.add_argument('--server-source')
    app.add_argument('--environment')
    app.add_argument('--api-version')
    for platform in ('ios', 'android'):
        app.add_argument(f'--{platform}-build')
        app.add_argument(f'--{platform}-source')
        app.add_argument(f'--{platform}-store-history')
    args = parser.parse_args()
    try:
        result = prepare_backend(args) if args.command == 'backend' else prepare_app(args)
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
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
