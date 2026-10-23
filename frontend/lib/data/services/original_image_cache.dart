import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Stores only verified original bytes. Access authorization belongs to the API.
class OriginalImageCache {
  OriginalImageCache({
    Future<Directory> Function()? directory,
    DateTime Function()? now,
    this.maxBytes = 100 * 1024 * 1024,
  }) : directory = directory ?? _appDirectory,
       _now = now ?? DateTime.now;

  static Future<Directory> _appDirectory() async {
    final cache = await getApplicationCacheDirectory();
    return Directory('${cache.path}/clipback-originals-v1');
  }

  final Future<Directory> Function() directory;
  final DateTime Function() _now;
  final int maxBytes;
  static const _maxUnused = Duration(days: 7);
  Future<void> _queue = Future.value();
  int _generation = 0;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// Cancels pending writes immediately; removes files behind any active I/O.
  void invalidate() {
    _generation++;
    unawaited(
      _serial(() async {
        try {
          final root = await directory();
          if (!await root.exists()) return;
          await for (final file in root.list(followLinks: false)) {
            await file.delete(recursive: true);
          }
        } catch (_) {
          // Device cache failures must never prevent clearing an app session.
        }
      }),
    );
  }

  String _key(String environment, int userId, int assetId, String digest) =>
      sha256
          .convert(
            utf8.encode(jsonEncode([environment, userId, assetId, digest])),
          )
          .toString();

  Future<void> _prune(Directory root, {int reserveBytes = 0}) async {
    if (!await root.exists()) return;
    final retained = <({File file, FileStat stat})>[];
    var total = reserveBytes;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      if (!entity.path.endsWith('.image') ||
          _now().difference(stat.modified) >= _maxUnused) {
        await entity.delete();
      } else {
        retained.add((file: entity, stat: stat));
        total += stat.size;
      }
    }
    retained.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final entry in retained) {
      if (total <= maxBytes) break;
      await entry.file.delete();
      total -= entry.stat.size;
    }
  }

  Future<Uint8List?> read({
    required String environment,
    required int userId,
    required int assetId,
    required String digest,
    required int sizeBytes,
  }) {
    final generation = _generation;
    return _serial(() async {
      if (generation != _generation) return null;
      try {
        final root = await directory();
        await _prune(root);
        final file = File(
          '${root.path}/${_key(environment, userId, assetId, digest)}.image',
        );
        if (!await file.exists()) return null;
        if (await file.length() != sizeBytes) {
          await file.delete();
          return null;
        }
        final bytes = await file.readAsBytes();
        if (sha256.convert(bytes).toString() != digest) {
          await file.delete();
          return null;
        }
        await file.setLastModified(_now());
        return generation == _generation ? bytes : null;
      } catch (_) {
        return null;
      }
    });
  }

  Future<void> write({
    required String environment,
    required int userId,
    required int assetId,
    required String digest,
    required Uint8List bytes,
    required bool Function() isCurrent,
  }) {
    final generation = _generation;
    bool current() => generation == _generation && isCurrent();
    return _serial(() async {
      if (!current() ||
          bytes.length > maxBytes ||
          sha256.convert(bytes).toString() != digest) {
        return;
      }
      try {
        final root = await directory();
        if (!current()) return;
        await root.create(recursive: true);
        await _prune(root, reserveBytes: bytes.length);
        final file = File(
          '${root.path}/${_key(environment, userId, assetId, digest)}.image',
        );
        if (!current()) return;
        final partial = File('${file.path}.part');
        try {
          await partial.writeAsBytes(bytes, flush: true);
          await partial.setLastModified(_now());
          if (current()) await partial.rename(file.path);
          if (!current() && await file.exists()) await file.delete();
        } finally {
          if (await partial.exists()) await partial.delete();
        }
      } catch (_) {
        // A cache miss or full disk does not hide a valid downloaded original.
      }
    });
  }
}
