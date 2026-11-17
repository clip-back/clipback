// #423 정렬 팝업은 실제 플랫폼 글자 배율에서도 선택 줄(문구·체크)이 넘치지 않는다.
// 선형 배율(textScaleFactorTestValue)은 Android 14+ 비선형 1.3과 iOS xxxL을
// 재현하지 못하므로, 루트 앱 병합 테마·실제 Pretendard 위에 배율을 직접 넣는다.
// Flutter는 같은 위젯의 넘침을 한 번만 알리므로 환경·선택마다 테스트를 따로 둔다.
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/app_startup.dart';
import 'support/archive_all_preview.dart' as isolated;
import 'support/theme_font_app.dart';

/// Android 14+ 글자 크기 1.3배 표. Android SDK android-36.1
/// `android/content/res/FontScaleConverterFactory.java:101–108`을 옮겼다.
/// 표 사이는 선형 보간한다(같은 파일의 FontScaleConverterImpl).
class _AndroidNonlinear13 extends TextScaler {
  const _AndroidNonlinear13();

  static const _fromSp = [8.0, 10, 12, 14, 18, 20, 24, 30, 100];
  static const _toDp = [10.4, 13, 15.6, 18.8, 21.6, 23.6, 26.4, 30, 100];

  @override
  double get textScaleFactor => 1.3;

  @override
  double scale(double fontSize) {
    if (fontSize <= _fromSp.first) {
      return fontSize * _toDp.first / _fromSp.first;
    }
    for (var i = 1; i < _fromSp.length; i++) {
      if (fontSize <= _fromSp[i]) {
        final t = (fontSize - _fromSp[i - 1]) / (_fromSp[i] - _fromSp[i - 1]);
        return _toDp[i - 1] + (_toDp[i] - _toDp[i - 1]) * t;
      }
    }
    return fontSize;
  }

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => this;
}

void main() {
  setUpAll(loadPretendard);

  test('Android 비선형 1.3 표는 14sp를 18.8로 키운다', () {
    expect(const _AndroidNonlinear13().scale(14), closeTo(18.8, 1e-9));
    expect(const _AndroidNonlinear13().scale(16), closeTo(20.2, 1e-9));
  });

  final envs = <(String, TargetPlatform, TextScaler)>[
    ('Android 비선형 1.3', TargetPlatform.android, const _AndroidNonlinear13()),
    // iOS 비접근성 최대 단계 xxxL(23/17, FlutterViewController.mm).
    ('iOS xxxL', TargetPlatform.iOS, const TextScaler.linear(23 / 17)),
  ];

  for (final (name, platform, scaler) in envs) {
    for (final bookmarkedFirst in [false, true]) {
      final label = bookmarkedFirst ? '즐겨찾기 우선' : '최신순';
      testWidgets('정렬 팝업은 $name·$label 선택에서 넘치지 않는다', (t) async {
        expect(pretendardLoaded(), isTrue, reason: 'Pretendard did not load');
        final server = ThemeFontServer();
        t.view.physicalSize = const Size(320, 852);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        debugDefaultTargetPlatformOverride = platform;
        try {
          await http.runWithClient(() async {
            try {
              await t.pumpWidget(
                Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: scaler),
                    child: ClipbackApp(
                      sessionStorage: isolated.ArchiveAllMemoryStorage(),
                      socialAuth: isolated.ArchiveAllSocialAuth(),
                    ),
                  ),
                ),
              );
              await completeAppStartup(t);
              await showOnApp(
                t,
                ArchiveToolbar(
                  countLabel: '총 1개',
                  sortLabel: label,
                  onSortChanged: (_) {},
                  archiveAllStyle: true,
                ),
              );
              await t.tap(find.byType(ArchiveSortButton));
              await t.pumpAndSettle();

              final item = find.ancestor(
                of: find.text(label).last,
                matching: find.byType(PopupMenuItem<bool>),
              );
              final text = find.descendant(
                of: item,
                matching: find.text(label),
              );
              expect(
                MediaQuery.textScalerOf(t.element(text)).scale(14),
                scaler.scale(14),
                reason: '팝업 문구가 넣은 배율을 받는다',
              );
              expect(
                find.descendant(of: item, matching: find.byIcon(Icons.check)),
                findsOneWidget,
              );
              expect(
                t.getRect(text).right,
                lessThanOrEqualTo(t.getRect(item).right),
              );
              expect(t.takeException(), isNull);
              expect(server.base.unexpected, isEmpty);
            } finally {
              await t.pumpWidget(const SizedBox.shrink());
              await t.pump();
            }
          }, () => server.client);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
