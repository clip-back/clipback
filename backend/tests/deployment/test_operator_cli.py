"""Operator CLI settings, streaming verification and bounded status output."""

import hashlib
import json
import os
import subprocess
import sys

import boto3
import pytest
from moto import mock_aws

from scripts.check_backup_restore import CheckError
from scripts.image_backup import BackupBucket, verify_backup
from scripts.operator_runtime import MaintenanceSettings, OperatorSettings


def test_maintenance_needs_no_original_storage_or_provider_settings(monkeypatch):
    for key in list(os.environ):
        if key.startswith(("STORAGE_", "S3_", "OPERATOR_", "DELETION_")):
            monkeypatch.delenv(key)
    config = MaintenanceSettings(
        database_url="postgresql://user:secret@localhost/db", app_environment="production",
        deletion_ledger_backend="s3", deletion_ledger_s3_endpoint_url="https://ledger.invalid",
        deletion_ledger_s3_bucket="ledger", deletion_ledger_s3_access_key_id="key",
        deletion_ledger_s3_secret_access_key="secret",
    )
    assert config.database_url.startswith("postgresql+asyncpg:")
    assert not hasattr(config, "storage_root")
    with pytest.raises(ValueError):
        OperatorSettings(**config.model_dump())


@pytest.mark.parametrize('command,extra,expected', [
    ('scripts.image_backup_jobs', ['daily'], 'backup_configuration_missing'),
    ('scripts.image_backup_jobs', ['maintain'], 'backup_configuration_missing'),
    ('scripts.image_backup', ['verify', '--backup-id', 'point'], 'backup_configuration_missing'),
])
def test_real_cli_fails_without_secrets_or_tracebacks(command, extra, expected):
    env = {'PATH': os.environ['PATH'], 'IMAGE_BACKUP_APP_COMMIT': 'a' * 40}
    result = subprocess.run([sys.executable, '-m', command, *extra], env=env,
                            capture_output=True, text=True)
    assert result.returncode == 1
    assert json.loads(result.stdout) == {'passed': False, 'error': expected}
    assert result.stderr == ''


@pytest.mark.parametrize('raw', ['secret-not-json', '{"secret_access_key":"private-value"}'])
def test_invalid_environment_configuration_is_redacted(raw):
    env = {'PATH': os.environ['PATH'], 'BACKUP_BUCKET_CONFIG_JSON': raw}
    result = subprocess.run([sys.executable, '-m', 'scripts.image_backup_jobs', 'maintain'],
                            env=env, capture_output=True, text=True)
    assert result.returncode == 1
    assert json.loads(result.stdout) == {'passed': False, 'error': 'invalid_credentials'}
    assert result.stderr == ''
    assert raw not in result.stdout


def test_environment_config_consumed_without_private_file(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv('BACKUP_BUCKET_CONFIG_JSON', json.dumps({
        'endpoint_url': 'http://127.0.0.1:5000', 'bucket': 'backups',
        'access_key_id': 'test', 'secret_access_key': 'secret',
    }))
    assert BackupBucket.from_environment().bucket == 'backups'
    assert 'BACKUP_BUCKET_CONFIG_JSON' not in os.environ
    assert list(tmp_path.iterdir()) == []


@mock_aws
def test_verify_streams_mixed_point_and_rejects_corrupt_or_missing_objects(tmp_path, monkeypatch):
    client = boto3.client('s3', region_name='us-east-1')
    client.create_bucket(Bucket='backups')
    store = BackupBucket(client, 'backups')
    assets = []
    for backend, data in [('local', b'volume'), ('s3', b'bucket')]:
        digest = hashlib.sha256(data).hexdigest()
        key = 'originals/sha256/' + digest
        client.put_object(Bucket='backups', Key=key, Body=data)
        assets.append({'storage_backend': backend, 'backup_key': key,
                       'sha256': digest, 'size_bytes': len(data)})
    database = {'backup_key': 'points/point/database.dump', 'size_bytes': 4,
                'sha256': hashlib.sha256(b'dump').hexdigest()}
    client.put_object(Bucket='backups', Key=database['backup_key'], Body=b'dump')
    manifest = {'format_version': 2, 'backup_id': 'point', 'database': database,
                'assets': assets, 'captured_at': '2026-10-26T00:00:00+00:00',
                'app_commit': 'a' * 40, 'migration_revisions': ['head'],
                'deletion_checkpoint': {'sequence': 0}}
    client.put_object(Bucket='backups', Key='points/point/manifest.json',
                      Body=json.dumps(manifest).encode())
    monkeypatch.chdir(tmp_path)
    result = verify_backup(store, 'point')
    assert result['asset_counts'] == {'local': 1, 's3': 1}
    assert result['verified_objects'] == 3 and result['total_bytes'] == 16
    assert result['restore_verified'] is False
    assert result['live_deletion_ledger_verified'] is False
    assert list(tmp_path.iterdir()) == []
    client.put_object(Bucket='backups', Key=assets[1]['backup_key'], Body=b'broken')
    with pytest.raises(CheckError, match='backup_hash_mismatch'):
        verify_backup(store, 'point')
    client.delete_object(Bucket='backups', Key='points/point/manifest.json')
    with pytest.raises(FileNotFoundError):
        verify_backup(store, 'point')


def test_status_filters_metadata_and_never_executes_shell(monkeypatch):
    from scripts.operator_status import cron_status, pr_status

    commands = []
    def run(command, **kwargs):
        assert not kwargs.get('shell')
        commands.append(command)
        if command[0] == 'railway':
            data = [{'id': 'run', 'status': 'EXITED', 'meta': {'secret': 'sensitive'}}]
        else:
            data = {'state': 'OPEN', 'statusCheckRollup': [
                {'name': 'test', 'status': 'COMPLETED', 'conclusion': 'SUCCESS',
                 'unneeded': 'sensitive'}]}
        return subprocess.CompletedProcess(command, 0, json.dumps(data))
    monkeypatch.setattr(subprocess, 'run', run)
    assert 'sensitive' not in json.dumps(cron_status('backup', 'production'))
    assert pr_status(104)['checks'][0]['conclusion'] == 'SUCCESS'
    assert all('run' not in command for command in commands)


def test_status_failure_is_nonzero_and_redacts_provider_stderr(monkeypatch, capsys):
    from scripts.operator_status import main

    def fail(*args, **kwargs):
        raise subprocess.CalledProcessError(1, ['railway'], stderr='private-provider-output')
    monkeypatch.setattr(subprocess, 'run', fail)
    monkeypatch.setattr(sys, 'argv', ['status', 'cron', '--service', 'backup'])
    assert main() == 1
    output = capsys.readouterr()
    assert json.loads(output.out) == {'passed': False, 'error': 'status_query_failed'}
    assert output.err == ''
