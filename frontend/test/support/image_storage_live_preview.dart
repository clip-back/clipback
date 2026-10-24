// Local integration entrypoint: real HTTP, session storage, cache and native share.
// Only the file picker and external social provider boundary are deterministic.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/clipback_api.dart';
import 'package:clipback_frontend/features/account/account_management_screen.dart';
import 'package:clipback_frontend/features/account/logout_confirmation_screen.dart';
import 'package:clipback_frontend/features/account/my_screen.dart';
import 'package:clipback_frontend/features/auth/interest_selection_screen.dart';
import 'package:clipback_frontend/features/auth/login_screen.dart';
import 'package:clipback_frontend/features/auth/onboarding_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/content/save_content_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/contracts/app_route.dart';
import 'package:clipback_frontend/shared/theme/assets.dart';
import 'package:clipback_frontend/social_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/photo_pending_fixture.dart'
    show PendingPhoto, PendingPhotoPicker;

final _rootKey = GlobalKey();
final _errors = <String>[];
final _requests = <Map<String, Object?>>[];
late IOClient _wire;
late SharedPreferences _preferences;
var _pointer = 900;
int? _userId;
bool _bucketCredentialsAbsent = true;
const _base = String.fromEnvironment('CLIPBACK_API_BASE_URL');
Element get _root => _rootKey.currentContext! as Element;

Iterable<Element> _elements(Element node) sync* {
  yield node;
  final children = <Element>[];
  node.visitChildren(children.add);
  for (final child in children) {
    yield* _elements(child);
  }
}

Element? _find<T extends Widget>() =>
    _elements(_root).where((e) => e.widget is T).firstOrNull;
Element? _text(String value) => _elements(_root)
    .where((e) => e.widget is Text && (e.widget as Text).data == value)
    .firstOrNull;
Element? _key(String value) =>
    _elements(_root).where((e) => e.widget.key == ValueKey(value)).firstOrNull;
Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 70));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 8),
    );
  }
}

Future<void> _wait(bool Function() condition, String why) async {
  for (var i = 0; i < 160; i++) {
    if (condition()) return;
    await _settle();
  }
  throw StateError(why);
}

Future<void> _tap(Element element) async {
  await Scrollable.ensureVisible(element);
  await _settle();
  final box = element.findRenderObject()! as RenderBox;
  final point = box.localToGlobal(box.size.center(Offset.zero));
  final id = ++_pointer, viewId = View.of(_root).viewId;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: id, viewId: viewId, position: point),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: id, viewId: viewId, position: point),
  );
  await _settle();
}

class _Observer extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bucket = request.url.port == 55465;
    if (bucket) {
      final names = request.headers.keys.map((e) => e.toLowerCase());
      _bucketCredentialsAbsent &=
          !names.contains('authorization') && !names.contains('cookie');
      if (!_bucketCredentialsAbsent) {
        throw StateError('Credentials reached Bucket');
      }
    }
    final response = await _wire.send(request);
    final record = <String, Object?>{
      'method': request.method,
      'route': bucket ? 'bucket' : request.url.path,
      'status': response.statusCode,
      'bytes': 0,
    };
    _requests.add(record);
    final body = <int>[];
    final stream = response.stream
        .map((chunk) {
          record['bytes'] = (record['bytes']! as int) + chunk.length;
          if (request.url.path.endsWith('/users/me') ||
              request.url.path.endsWith('/uploads/screenshots')) {
            body.addAll(chunk);
          }
          return chunk;
        })
        .transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleDone: (sink) {
              if (response.statusCode == 200 || response.statusCode == 201) {
                try {
                  if (body.isNotEmpty) {
                    final value =
                        jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
                    if (request.url.path.endsWith('/users/me')) {
                      _userId = value['id'] as int;
                    }
                    if (request.url.path.endsWith('/uploads/screenshots')) {
                      unawaited(
                        _preferences.setInt(
                          'image74_content',
                          value['id'] as int,
                        ),
                      );
                      final assets = value['assets'] as List;
                      if (assets.isNotEmpty) {
                        unawaited(
                          _preferences.setInt(
                            'image74_asset',
                            (assets.first as Map)['id'] as int,
                          ),
                        );
                      }
                    }
                  }
                } catch (_) {
                  _errors.add('observer response classification failed');
                }
              }
              sink.close();
            },
          ),
        );
    return http.StreamedResponse(
      stream,
      response.statusCode,
      headers: response.headers,
      contentLength: response.contentLength,
      request: response.request,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {} // Shared real transport lives for the process.
}

class _Social extends SocialAuth {
  @override
  List<SocialLoginProvider> get supportedProviders => const [];
  @override
  Future<SocialCredential?> authenticate(
    SocialLoginProvider provider, {
    String? nonce,
  }) async => null;
  @override
  Future<void> signOut([SocialLoginProvider? provider]) async {}
  @override
  Future<void> rememberAppleUserId(String? userId) async {}
  @override
  Future<AppleCredentialStatus> appleCredentialState() async =>
      AppleCredentialStatus.unavailable;
}

Future<void> _login() async {
  await _wait(() => _find<LoginScreen>() != null, 'Login screen missing');
  await (_find<LoginScreen>()!.widget as LoginScreen).onContinue();
  await _wait(
    () => _find<OnboardingScreen>() != null || _find<HomeScreen>() != null,
    'Guest login did not complete',
  );
  if (_find<OnboardingScreen>() != null) {
    for (var i = 0; i < 2; i++) {
      await _tap(_text('다음')!);
    }
    await _tap(_text('시작하기')!);
    await _wait(
      () => _find<InterestSelectionScreen>() != null,
      'Interests missing',
    );
    (_find<InterestSelectionScreen>()!.widget as InterestSelectionScreen)
        .onDone();
  }
  await _wait(
    () => _find<HomeScreen>() != null && _userId != null,
    'Home missing',
  );
}

Future<void> _normalSave() async {
  if (_find<AddContentSheet>() != null) {
    await _tap(_find<SaveFlowButton>()!);
    return;
  }
  final nav = _elements(
    _root,
  ).firstWhere((e) => e.widget.runtimeType.toString() == 'NavAddButton');
  await _tap(nav);
  await _tap(_text('사진 첨부')!);
  await _tap(_text('사진 선택')!);
  await _wait(
    () => _find<SelectedPhotoPreview>() != null,
    'Selected image missing',
  );
  await _tap(_find<SaveFlowButton>()!);
  await _settle();
}

Future<void> _home() async {
  final detail = _find<DetailScreen>();
  if (detail != null) (detail.widget as DetailScreen).onBack();
  final result = _find<SavedContentConfirmation>();
  if (result != null) {
    (_find<SaveContentTopBar>()!.widget as SaveContentTopBar).onClose();
    await _settle();
  }
  await _wait(() => _find<HomeScreen>() != null, 'Home missing');
}

Future<Map<String, Object?>> _state() async {
  final cache = Directory(
    '${(await getApplicationCacheDirectory()).path}/clipback-originals-v1',
  );
  final files = await cache.exists()
      ? await cache
            .list()
            .where((e) => e is File && e.path.endsWith('.image'))
            .cast<File>()
            .toList()
      : <File>[];
  final hashes = <String>[];
  var bytes = 0;
  for (final file in files) {
    final data = await file.readAsBytes();
    bytes += data.length;
    hashes.add(sha256.convert(data).toString());
  }
  final native = await const MethodChannel(
    'com.huturu.app/share',
  ).invokeMapMethod<String, Object?>('getState');
  final home = _find<HomeScreen>()?.widget as HomeScreen?;
  return {
    'platform': Platform.operatingSystem,
    'user_id': _userId,
    'route': _find<LoginScreen>() != null
        ? 'login'
        : _find<DetailScreen>() != null
        ? 'detail'
        : home != null
        ? 'home'
        : _find<SavedContentConfirmation>() != null
        ? 'result'
        : 'other',
    'home_content_ids': home?.contents.map((e) => e.apiId).toList(),
    'saved_content_id': _preferences.getInt('image74_content'),
    'saved_asset_id': _preferences.getInt('image74_asset'),
    'cache_files': files.length,
    'cache_bytes': bytes,
    'cache_sha256': hashes,
    'descriptor_gets': _requests
        .where((e) => (e['route']! as String).endsWith('/access'))
        .length,
    'bucket_gets': _requests
        .where((e) => e['route'] == 'bucket' && e['method'] == 'GET')
        .length,
    'bucket_credentials_absent': _bucketCredentialsAbsent,
    'native_state': native,
    'requests': _requests,
    'errors': _errors,
    'image_visible': _elements(_root).any(
      (e) =>
          e.widget is Image &&
          (e.widget as Image).semanticLabel == '저장한 스크린샷 원본',
    ),
    'texts': _elements(_root)
        .where((e) => e.widget is Text)
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .toSet()
        .toList(),
  };
}

Future<void> _control(HttpRequest request) async {
  try {
    switch (request.uri.path) {
      case '/login':
        await _login();
      case '/save':
        await _normalSave();
      case '/home':
        await _home();
      case '/close-save':
        (_find<SaveContentTopBar>()!.widget as SaveContentTopBar).onClose();
        await _settle();
      case '/original':
        await _home();
        final home = _find<HomeScreen>()!.widget as HomeScreen;
        final id = _preferences.getInt('image74_content');
        home.onOpenContent(home.contents.firstWhere((e) => e.apiId == id));
        await _wait(
          () => _key('detail-original-button') != null,
          'Detail missing',
        );
        await _tap(_key('detail-original-button')!);
        await _wait(
          () => _elements(_root).any(
            (e) =>
                e.widget is Image &&
                (e.widget as Image).semanticLabel == '저장한 스크린샷 원본',
          ),
          'Original missing',
        );
      case '/close-sheet':
        Navigator.of(_key('detail-original-button')!).pop();
        await _settle();
      case '/logout':
        await _home();
        (_find<HomeScreen>()!.widget as HomeScreen).onTab(AppRoute.my);
        await _settle();
        (_find<MyScreen>()!.widget as MyScreen).onOpenAccount();
        await _settle();
        await (_find<AccountManagementScreen>()!.widget
                as AccountManagementScreen)
            .onLogout();
        await _settle();
        await (_find<LogoutConfirmationScreen>()!.widget
                as LogoutConfirmationScreen)
            .onConfirm();
        await _wait(() => _find<LoginScreen>() != null, 'Logout missing');
        _userId = null;
      case '/old-access':
        final session = await ApiSessionStorage().read();
        final id = _preferences.getInt('image74_asset');
        final response = await _wire.get(
          Uri.parse('$_base/uploads/assets/$id/access'),
          headers: {'Authorization': 'Bearer ${session!.accessToken}'},
        );
        _requests.add({
          'route': 'old-account-access',
          'status': response.statusCode,
          'bytes': response.bodyBytes.length,
        });
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(await _state()));
  } catch (error) {
    request.response.statusCode = 500;
    request.response.write(jsonEncode({'error': error.toString()}));
  }
  await request.response.close();
}

Future<void> main() async {
  _wire = IOClient(HttpClient());
  await http.runWithClient(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (!['127.0.0.1', '10.0.2.2'].contains(Uri.parse(_base).host) ||
        Uri.parse(_base).port != 18766) {
      throw StateError('An explicit local image validation API is required');
    }
    _preferences = await SharedPreferences.getInstance();
    final data = await rootBundle.load(Assets.savedPhotoPreview);
    FilePicker.platform = PendingPhotoPicker([
      PendingPhoto('image74.png', data.buffer.asUint8List()),
    ]);
    FlutterError.onError = (details) {
      _errors.add(details.exceptionAsString());
      FlutterError.presentError(details);
    };
    runApp(
      SizedBox(
        key: _rootKey,
        child: ClipbackApp(socialAuth: _Social()),
      ),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
    server.listen(_control);
  }, _Observer.new);
}
