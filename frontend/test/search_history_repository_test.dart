import 'dart:async';
import 'package:clipback_frontend/data/repositories/search_history_repository.dart';
import 'package:clipback_frontend/data/services/search_history_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryHistory implements SearchHistoryStorage {
  final values = <String, List<String>>{};
  final writes = <String>[];
  Completer<List<String>>? readGate;
  Completer<void>? writeGate;
  bool failRead = false, failWrite = false;
  int reads = 0, activeWrites = 0, maxWrites = 0;
  String key(String e, int id) => '$e/$id';
  @override
  Future<List<String>> read(String e, int id) async {
    reads++;
    if (failRead) throw StateError('read');
    if (readGate != null) return readGate!.future;
    return List.of(values[key(e, id)] ?? []);
  }

  @override
  Future<void> write(String e, int id, List<String> terms) async {
    activeWrites++;
    if (activeWrites > maxWrites) maxWrites = activeWrites;
    try {
      await writeGate?.future;
      if (failWrite) throw StateError('write');
      values[key(e, id)] = List.of(terms);
      writes.add(key(e, id));
    } finally {
      activeWrites--;
    }
  }
}

void main() {
  late MemoryHistory s;
  late SearchHistoryRepository r;
  setUp(() {
    s = MemoryHistory();
    r = SearchHistoryRepository(storage: s, environment: 'test');
    r.bind(generation: 1, active: true, userId: 1);
  });
  tearDown(() => r.dispose());
  test(
    'empty, submitted terms, trim only, dedupe, max five and deletion',
    () async {
      r.open();
      await r.settle();
      expect(r.terms, isEmpty);
      for (final q in [' A  B ', 'a  b', 'c', 'd', 'e', 'f', ' A  B ', '   ']) {
        r.record(q);
      }
      await r.settle();
      expect(r.terms, ['A  B', 'f', 'e', 'd', 'c']);
      r.remove('f');
      await r.settle();
      expect(s.values['test/1'], ['A  B', 'e', 'd', 'c']);
    },
  );
  test('late initial read replays submitted and deleted terms', () async {
    s.readGate = Completer();
    r.open();
    r.record('new');
    r.remove('old');
    r.record('last');
    s.readGate!.complete(['old', 'stored']);
    await r.settle();
    expect(r.terms, ['last', 'new', 'stored']);
    expect(s.values['test/1'], r.terms);
  });
  test(
    'writes serialize and final snapshot includes concurrent edits',
    () async {
      r.open();
      await r.settle();
      s.writeGate = Completer();
      r.record('a');
      r.record('b');
      r.remove('a');
      r.record('c');
      s.writeGate!.complete();
      await r.settle();
      expect(s.maxWrites, 1);
      expect(s.values['test/1'], ['c', 'b']);
    },
  );
  test('write failure keeps memory and next explicit edit retries', () async {
    r.open();
    await r.settle();
    s.failWrite = true;
    r.record('a');
    await r.settle();
    expect(r.terms, ['a']);
    expect(s.writes, isEmpty);
    s.failWrite = false;
    r.open();
    await r.settle();
    expect(s.writes, isEmpty);
    r.record('b');
    await r.settle();
    expect(s.values['test/1'], ['b', 'a']);
  });
  test(
    'read failure never overwrites disk and reentry replays edits',
    () async {
      s.values['test/1'] = ['stored'];
      s.failRead = true;
      r.open();
      await r.settle();
      r.record('a');
      await r.settle();
      expect(s.reads, 1);
      expect(s.writes, isEmpty);
      expect(r.terms, ['a']);
      s.failRead = false;
      r.open();
      await r.settle();
      expect(s.values['test/1'], ['a', 'stored']);
    },
  );
  test('accounts, logout, stale owner and return to same user', () async {
    r.open();
    r.record('one');
    await r.settle();
    final old = r.owner;
    r.bind(generation: 2, active: false);
    expect(r.terms, isEmpty);
    expect(r.owns(old), false);
    r.bind(generation: 3, active: true, userId: 2);
    r.open();
    r.record('two');
    await r.settle();
    expect(r.terms, ['two']);
    r.bind(generation: 4, active: true, userId: 1);
    r.open();
    await r.settle();
    expect(r.terms, ['one']);
  });
  test(
    'unknown identity uses temporary edits and same generation attaches',
    () async {
      r.bind(generation: 2, active: true);
      r.open();
      r.record('temporary');
      r.remove('old');
      final owner = r.owner;
      expect(s.reads, 0);
      s.values['test/1'] = ['old', 'existing'];
      r.bind(generation: 2, active: true, userId: 1);
      await r.settle();
      expect(r.owns(owner), true);
      expect(r.terms, ['temporary', 'existing']);
    },
  );
  test('unknown identity edits are discarded on generation change', () async {
    r.bind(generation: 2, active: true);
    r.record('discard');
    r.bind(generation: 3, active: true, userId: 2);
    r.open();
    await r.settle();
    expect(r.terms, isEmpty);
  });
  test(
    'late old account read/write cannot replace active account display',
    () async {
      final gate = Completer<List<String>>();
      s.readGate = gate;
      r.open();
      r.record('accepted');
      r.bind(generation: 2, active: true, userId: 2);
      s.readGate = null;
      r.open();
      r.record('two');
      gate.complete(['one']);
      await r.settle();
      expect(r.terms, ['two']);
      expect(s.values['test/1'], ['accepted', 'one']);
    },
  );
  test('dispose finishes accepted write without notifications', () async {
    final other = SearchHistoryRepository(storage: s, environment: 'other');
    other.bind(generation: 1, active: true, userId: 1);
    other.open();
    other.record('kept');
    other.dispose();
    await other.settle();
    expect(s.values['other/1'], ['kept']);
    expect(s.values['test/1'], isNull);
  });
  test(
    'new app repository restores and same ID upgrade keeps history',
    () async {
      r.open();
      r.record('guest');
      await r.settle();
      final next = SearchHistoryRepository(storage: s, environment: 'test');
      next.bind(generation: 4, active: true, userId: 1);
      next.open();
      await next.settle();
      expect(next.terms, ['guest']);
      next.dispose();
    },
  );
  test('stored values normalize without manufacturing examples', () async {
    s.values['test/1'] = ['', ' A ', 'A', 'a', '  ', 'b', 'c', 'd', 'e'];
    r.open();
    await r.settle();
    expect(r.terms, ['A', 'a', 'b', 'c', 'd']);
    expect(s.writes, isEmpty);
  });
}
