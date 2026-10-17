// G02/G11: deterministic direct-screen visual evidence is separate from the
// actual root app integration run. No provider or production proof is claimed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:clipback_frontend/app/clipback_app.dart';
import 'package:clipback_frontend/features/archive/archive_screen.dart';
import 'package:clipback_frontend/features/archive/archive_widgets.dart';
import 'package:clipback_frontend/features/archive/category_card_review_screen.dart';
import 'package:clipback_frontend/features/content/detail_screen.dart';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/theme/app_colors.dart';
import 'package:clipback_frontend/shared/widgets/app_layout.dart';
import 'package:clipback_frontend/shared/widgets/navigation_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'archive_all_preview.dart' as e01;

const reviewPhase = String.fromEnvironment(
  'CARD_REVIEW_ALIGNMENT_PHASE',
  defaultValue: 'before',
);
const reviewAssets = {
  'active': 'assets/icons/review-progress-active.svg',
  'inactive': 'assets/icons/review-progress-inactive.svg',
};
List<ContentItem> reviewContents({
  int count = 5,
  bool longTitle = false,
  bool shortBody = false,
  bool figmaExample = false,
  bool originalEmpty = false,
  bool longBadge = false,
}) => List.generate(count, (i) {
  final source = e01.archiveAllContents()[i % 5];
  return ContentItem(
    id: 'review-${i + 1}',
    apiId: 601 + i,
    title: figmaExample && i == 0
        ? '자소서 합격률 UP\n이건 무조건! 적용해야 합니다'
        : longTitle
        ? '아주 긴 제목을 두 줄까지 표시하고 필요한 본문 공간을 실제 남은 높이에 맞추어 보존합니다'
        : '다시 확인할 정보 ${i + 1}',
    summary: '원문이 없을 때 실제 요약을 표시해요.',
    category: figmaExample
        ? source.category.copyWith(
            name: '취업준비',
            color: AppColors.main,
            tint: AppColors.mainSubtle,
            deep: AppColors.mainDeep,
          )
        : longBadge
        ? source.category.copyWith(name: '아주 길어도 실제 카테고리 이름과 색상을 보존하는 배지')
        : source.category,
    savedAt: source.savedAt,
    savedAtFull: source.savedAtFull,
    savedAtFullShort: source.savedAtFullShort,
    tags: const [],
    source: 'web',
    originalUrl: source.originalUrl,
    originalText: originalEmpty
        ? ''
        : shortBody
        ? '저장한 원문을 다시 확인해요.'
        : List.filled(35, '저장한 정보를 다시 확인하고 필요한 순간에 활용해요.').join(' '),
  );
});
ThemeData reviewTheme({TargetPlatform? platform}) => ThemeData(
  useMaterial3: true,
  platform: platform,
  fontFamily: 'Pretendard',
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.main,
    surface: AppColors.bg,
  ),
  textTheme: ThemeData().textTheme.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  ),
);
List<Element> _elements(Element e) => e01.archiveAllElements(e);
Element? _find<T extends Widget>(Element e) => e01.archiveAllFind<T>(e);
Element? _key(Element e, String k) => e01.archiveAllKey(e, k);
Element? _text(Element e, String t) => e01.archiveAllText(e, t);
Rect _box(Element e) {
  final r = e.findRenderObject()! as RenderBox;
  return MatrixUtils.transformRect(
    r.getTransformTo(null),
    Offset.zero & r.size,
  );
}

Map<String, double> _rect(Rect r) => {
  'left': r.left,
  'top': r.top,
  'right': r.right,
  'bottom': r.bottom,
  'width': r.width,
  'height': r.height,
};
String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
Element? _ancestor(Element e, bool Function(Widget) predicate) {
  Element? found;
  e.visitAncestorElements((v) {
    if (predicate(v.widget)) {
      found = v;
      return false;
    }
    return true;
  });
  return found;
}

Map<String, Object?> _paragraph(Element e) {
  final p = e.findRenderObject()! as RenderParagraph;
  final s = (p.text as TextSpan).style!;
  return {
    'text': p.text.toPlainText(),
    'bounds': _rect(_box(e)),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'scaledFontSize': s.fontSize == null
        ? null
        : p.textScaler.scale(s.fontSize!),
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'color': _color(s.color),
    'maxLines': p.maxLines,
    'softWrap': p.softWrap,
    'localWidth': p.size.width,
    'localHeight': p.size.height,
    'textAlign': p.textAlign.name,
    'overflow': p.overflow.name,
    'didExceedMaxLines': p.didExceedMaxLines,
  };
}

Map<String, Object?> _asset(Element? root) {
  if (root == null) return {};
  final svg = root.widget is SvgPicture ? root : _find<SvgPicture>(root);
  if (svg != null) {
    final w = svg.widget as SvgPicture;
    return {
      'bounds': _rect(_box(svg)),
      'asset': w.bytesLoader is SvgAssetLoader
          ? (w.bytesLoader as SvgAssetLoader).assetName
          : null,
      'unfiltered': w.colorFilter == null,
      'localWidth': (svg.findRenderObject()! as RenderBox).size.width,
      'localHeight': (svg.findRenderObject()! as RenderBox).size.height,
    };
  }
  final image = root.widget is Image ? root : _find<Image>(root);
  if (image != null) {
    final w = image.widget as Image;
    ImageProvider p = w.image;
    if (p is ResizeImage) p = p.imageProvider;
    return {
      'bounds': _rect(_box(image)),
      'asset': p is AssetImage ? p.assetName : null,
      'fit': w.fit?.name,
    };
  }
  return {'bounds': _rect(_box(root)), 'asset': null};
}

Map<String, Object?> _surface(Element e) {
  final c = _elements(e)
      .where(
        (x) =>
            x.widget is Container &&
            (x.widget as Container).decoration is BoxDecoration,
      )
      .firstOrNull;
  if (c == null) return {};
  final d = (c.widget as Container).decoration! as BoxDecoration;
  return {
    'fill': _color(d.color),
    'radius': (d.borderRadius as BorderRadius?)?.topLeft.x,
    'shadows': [
      for (final v in d.boxShadow ?? <BoxShadow>[])
        {
          'color': _color(v.color),
          'blur': v.blurRadius,
          'spread': v.spreadRadius,
          'dx': v.offset.dx,
          'dy': v.offset.dy,
        },
    ],
  };
}

Map<String, Object?> reviewMeasure(Element root) {
  final screen = _find<CategoryCardReviewScreen>(root);
  if (screen == null) return {'active': false};
  final w = screen.widget as CategoryCardReviewScreen,
      media = MediaQuery.of(screen);
  final cards = _elements(
    screen,
  ).where((e) => e.widget is CategoryReviewCard).toList();
  final progress = _find<CardPagerProgress>(screen),
      front = _find<AnimatedSlide>(screen);
  final scaffold = _find<Scaffold>(screen)!;
  final vp = _key(screen, 'review-viewport') ?? _find<ClipRect>(screen);
  final exit = _text(screen, '나가기');
  final guide = _text(screen, '딱 5개만 다시 확인해볼까요?');
  final category = guide == null ? null : _text(screen, w.categoryName);
  final guideBox = guide == null
      ? null
      : (_key(screen, 'review-guide') ?? _ancestor(guide, (x) => x is Column));
  final cardList = <Map<String, Object?>>[];
  for (final e in cards) {
    final c = e.widget as CategoryReviewCard;
    final title = _text(e, c.content.title)!,
        body = _text(
          e,
          c.content.originalText.isNotEmpty
              ? c.content.originalText
              : c.content.summary,
        )!;
    final badge = _text(e, c.content.category.name)!;
    final bodyP = body.findRenderObject()! as RenderParagraph;
    final probe = TextPainter(
      text: TextSpan(text: '한', style: (bodyP.text as TextSpan).style),
      textDirection: bodyP.textDirection,
      textScaler: bodyP.textScaler,
    )..layout(maxWidth: bodyP.size.width);
    final lh = probe.preferredLineHeight;
    probe.dispose();
    final all = TextPainter(
      text: bodyP.text,
      textDirection: bodyP.textDirection,
      textScaler: bodyP.textScaler,
    )..layout(maxWidth: bodyP.size.width);
    final fullCount = all.computeLineMetrics().length;
    all.dispose();
    final rendered = TextPainter(
      text: bodyP.text,
      textDirection: bodyP.textDirection,
      textScaler: bodyP.textScaler,
      maxLines: bodyP.maxLines,
      ellipsis: bodyP.overflow == TextOverflow.ellipsis ? '…' : null,
    )..layout(maxWidth: bodyP.size.width);
    final lines = rendered.computeLineMetrics();
    final bottom = lines.isEmpty
        ? 0.0
        : lines.last.baseline + lines.last.descent;
    rendered.dispose();
    final slot = _key(screen, 'review-active-card');
    final isFront = front != null && _elements(front).contains(e);
    final bookmark =
        _key(e, 'review-bookmark-${c.content.id}') ??
        _elements(e)
            .where(
              (x) =>
                  x.widget is InkWell &&
                  (x.widget as InkWell).customBorder is CircleBorder,
            )
            .firstOrNull;
    cardList.add({
      'id': c.content.id,
      'front': isFront,
      'bounds': _rect(_box(e)),
      'slotBounds': _rect(
        isFront ? (slot == null ? _box(front) : _box(slot)) : _box(e),
      ),
      'localWidth': (e.findRenderObject()! as RenderBox).size.width,
      'localHeight': (e.findRenderObject()! as RenderBox).size.height,
      'title': _paragraph(title),
      'body': {
        ..._paragraph(body),
        'lineHeight': lh,
        'fullLineCount': fullCount,
        'renderedLineCount': lines.length,
        'lastPaintedLineBottom': bottom,
        'expectedFullLines': math.max(
          1,
          math.min(fullCount, (bodyP.size.height / lh + 1e-7).floor()),
        ),
      },
      'badge': _paragraph(badge),
      'rowBounds': _rect(_box(_ancestor(badge, (w) => w is Row)!)),
      'badgeSurface': _surface(_ancestor(badge, (w) => w is Container)!),
      'badgeColor': _color(c.content.category.deep),
      'badgeTint': _color(c.content.category.tint),
      'surface': _surface(e),
      'bookmarked': c.bookmarked,
      'mutationLabel': c.content.mutationLabel,
      if (bookmark != null) 'bookmarkHit': _rect(_box(bookmark)),
    });
  }
  final dots = <Map<String, Object?>>[];
  if (progress != null) {
    final p = progress.widget as CardPagerProgress;
    for (var i = 0; i < p.count; i++) {
      final d = _key(progress, 'review-progress-dot-$i');
      dots.add({
        'index': i,
        'active': i == p.activeIndex,
        if (d != null) 'bounds': _rect(_box(d)),
        'image': _asset(_key(progress, 'review-progress-image-$i')),
      });
    }
  }
  return {
    'active': true,
    'empty': w.contents.isEmpty,
    'complete': w.contents.isNotEmpty && cards.isEmpty,
    'screen': _rect(_box(scaffold)),
    if (vp != null) 'viewport': _rect(_box(vp)),
    if (_key(screen, 'review-header') case final h?) 'header': _rect(_box(h)),
    'guide': guide == null ? null : _paragraph(guide),
    'category': category == null ? null : _paragraph(category),
    if (guideBox != null) 'guideBox': _rect(_box(guideBox)),
    'folder': guideBox == null ? null : _asset(_find<SvgPicture>(guideBox)),
    'exit': exit == null ? null : _paragraph(exit),
    if (_find<TextButton>(screen) case final t?) 'exitHit': _rect(_box(t)),
    'backgrounds': [
      for (var d = 1; d <= 2; d++)
        if (_key(screen, 'review-background-$d') case final bg?)
          {'distance': d, 'bounds': _rect(_box(bg)), 'surface': _surface(bg)},
    ],
    'cards': cardList,
    'progress': progress == null
        ? null
        : {
            'bounds': _rect(_box(progress)),
            'activeIndex': (progress.widget as CardPagerProgress).activeIndex,
            'count': (progress.widget as CardPagerProgress).count,
            'dots': dots,
            'track': _asset(_key(progress, 'review-progress-track')),
            'trackSurface': _surface(
              _key(progress, 'review-progress-track') ?? progress,
            ),
            if (_key(screen, 'review-progress-region') case final region?)
              'region': _rect(_box(region)),
          },
    'dataIds': w.contents.map((c) => c.id).toList(),
    'categoryName': w.categoryName,
    'safeTop': media.viewPadding.top,
    'safeBottom': media.viewPadding.bottom,
    'textScale': media.textScaler.scale(1),
  };
}

Map<String, Object?> reviewJudgment(Map<String, Object?> m) {
  final sf = <String>[], lf = <String>[], af = <String>[];
  if (m['active'] != true || m['empty'] == true) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'assetPassed': true,
      'styleFailures': sf,
      'layoutFailures': lf,
      'assetFailures': af,
    };
  }
  bool near(Object? x, num y) => x is num && (x - y).abs() < .2;
  void n(Object? x, num y, String why) {
    if (!near(x, y)) lf.add('$why: $x != $y');
  }

  void style(
    Map? p,
    num size,
    int weight,
    num spacing,
    String color,
    num? height,
    String role,
  ) {
    if (p == null ||
        p['fontFamily'] != 'Pretendard' ||
        !near(p['fontSize'], size) ||
        !near(p['scaledFontSize'], size) ||
        p['fontWeight'] != weight ||
        !near(p['letterSpacing'], spacing) ||
        p['color'] != color ||
        height == null && p['height'] != null ||
        height != null && !near(p['height'], height)) {
      sf.add('$role: $p');
    }
  }

  final screen = m['screen'] as Map,
      vp = m['viewport'] as Map?,
      header = m['header'] as Map?;
  if (vp == null) {
    lf.add('safe clip missing');
  } else {
    n(vp['top'], m['safeTop'] as num, 'safe top');
    n(
      (screen['bottom'] as num) - (vp['bottom'] as num),
      m['safeBottom'] as num,
      'safe bottom once',
    );
  }
  if (header == null) {
    lf.add('header measurement missing');
  } else {
    n(header['height'], 64, 'header64');
    n(header['top'], m['safeTop'] as num, 'header top');
  }
  style(m['guide'] as Map?, 16, 600, -.4, '0xFFB5BDC3', null, 'guide');
  style(m['category'] as Map?, 24, 600, -.6, '0xFF1A1A1A', null, 'category');
  style(m['exit'] as Map?, 16, 500, -.4, '0xFF1A1A1A', null, 'exit');
  if (m['category'] != null && (m['category'] as Map)['maxLines'] != 1) {
    sf.add('category max1');
  }
  if (m['exit'] != null) {
    n(
      (screen['right'] as num) - ((m['exit'] as Map)['bounds']['right'] as num),
      16,
      'exit glyph right',
    );
  }
  if (m['exitHit'] is Map) {
    if (((m['exitHit'] as Map)['width'] as num) < 47.8 ||
        ((m['exitHit'] as Map)['height'] as num) < 43.8) {
      lf.add('exit hit below48x44');
    }
  }
  if (m['guideBox'] is Map) {
    n(
      ((m['guideBox'] as Map)['top'] as num) - (m['safeTop'] as num),
      64,
      'guide top',
    );
  }
  if (m['guideBox'] is Map) {
    n((m['guideBox'] as Map)['height'], 56, 'guide natural height');
  }
  final folder = m['folder'] as Map?;
  if (folder != null && folder['bounds'] is Map) {
    n(folder['bounds']['width'], 28.2353, 'folder width');
    n(folder['bounds']['height'], 24, 'folder height');
    n(
      ((m['category'] as Map)['bounds']['left'] as num) -
          (folder['bounds']['right'] as num),
      8,
      'folder category gap',
    );
    n(
      ((m['category'] as Map)['bounds']['top'] as num) -
          ((m['guide'] as Map)['bounds']['bottom'] as num),
      8,
      'guide category gap',
    );
  }
  final cards = m['cards'] as List;
  if (m['complete'] == true) {
    if (m['progress'] != null) lf.add('complete must hide progress');
    if (cards.isNotEmpty) lf.add('complete cards remain');
  } else {
    final f = cards.where((c) => c['front'] == true).firstOrNull;
    if (f == null) {
      lf.add('active front missing');
    } else {
      final r = f['slotBounds'] as Map;
      n(r['width'], (screen['width'] as num) - 32, 'front width');
      n(r['height'], 496, 'front height');
      n((r['top'] as num) - (m['safeTop'] as num), 196, 'front top');
      n((r['left'] as num) - (screen['left'] as num), 16, 'front left');
      n(f['surface']['radius'], 8, 'front radius');
      n(
        (f['rowBounds']['top'] as num) - (r['top'] as num),
        24,
        'row top padding',
      );
      if ((f['rowBounds']['height'] as num) < 27.8) {
        lf.add('row below min28');
      }
      n(
        (f['title']['bounds']['top'] as num) -
            (f['rowBounds']['bottom'] as num),
        8,
        'row title gap',
      );
      if (f['badgeSurface']['fill'] != f['badgeTint']) {
        lf.add('badge actual tint');
      }
      final shadows = f['surface']['shadows'] as List;
      if (shadows.isEmpty ||
          shadows.first['color'] != '0x29000000' ||
          !near(shadows.first['blur'], 8)) {
        lf.add('front shadow');
      }
      style(f['title'] as Map, 22, 600, -.55, '0xFF1A1A1A', 1.4, 'title');
      style(f['body'] as Map, 16, 400, -.4, '0xFF1A1A1A', 1.6, 'body');
      style(
        f['badge'] as Map,
        12,
        500,
        -.3,
        f['badgeColor'] as String,
        null,
        'badge',
      );
      if (f['title']['maxLines'] != 2 || f['title']['overflow'] != 'ellipsis') {
        sf.add('title two lines ellipsis');
      }
      if ((f['body']['lastPaintedLineBottom'] as num) >
          (f['body']['localHeight'] as num) + .2) {
        lf.add('body clips an actual painted line');
      }
      if (f['body']['overflow'] != 'ellipsis' ||
          f['body']['maxLines'] != f['body']['expectedFullLines']) {
        lf.add('body must use full actual lines: ${f['body']}');
      }
      n(
        (f['title']['bounds']['left'] as num) - (r['left'] as num),
        24,
        'front padding left',
      );
      n(
        (f['body']['bounds']['top'] as num) -
            (f['title']['bounds']['bottom'] as num),
        8,
        'title body gap',
      );
      final painted = f['bounds'] as Map;
      n(painted['width'], r['width'] as num, 'no rotation paint width');
      n(painted['height'], r['height'] as num, 'no rotation paint height');
    }
    final p = m['progress'] as Map?;
    if (p == null) {
      lf.add('progress missing');
    } else {
      n(p['bounds']['height'], 16, 'progress logical height');
      n(
        (p['bounds']['top'] as num) - (m['safeTop'] as num),
        142,
        'progress component top',
      );
      final reg = p['region'] as Map?;
      if (reg == null) {
        lf.add('progress region missing');
      } else {
        n(reg['height'], 60, 'progress region height');
        n(
          (reg['top'] as num) - (m['safeTop'] as num),
          120,
          'progress region top',
        );
      }
      final track = p['track'] as Map;
      if (track['bounds'] is Map) {
        n(track['bounds']['height'], 8, 'track height');
      } else {
        lf.add('track actual bounds missing');
      }
      if (p['trackSurface']['fill'] != '0xFFE4E4E4') {
        lf.add('track actual color');
      }
      if (p['count'] != (m['dataIds'] as List).length) {
        lf.add('actual progress count');
      }
      for (final d in p['dots']) {
        final active = d['active'] == true, im = d['image'] as Map;
        if (im['asset'] != reviewAssets[active ? 'active' : 'inactive'] ||
            im['unfiltered'] != true) {
          af.add('exact progress ${d['index']}');
        }
        n(im['localWidth'], active ? 20 : 8, 'progress original width');
        n(im['localHeight'], active ? 20 : 8, 'progress original height');
        if (d['bounds'] is Map && im['bounds'] is Map && active) {
          n(
            (im['bounds']['left'] as num) - (d['bounds']['left'] as num),
            -2,
            'active overscan left',
          );
          n(
            (im['bounds']['right'] as num) - (d['bounds']['right'] as num),
            2,
            'active overscan right',
          );
        }
        if (d['bounds'] is Map) {
          n(d['bounds']['width'], active ? 16 : 8, 'progress logical slot');
        }
      }
    }
    final measured = m['backgrounds'] as List;
    final bg = measured.isNotEmpty
        ? measured
        : cards.where((c) => c['front'] != true).toList().reversed.toList();
    final index = (m['progress'] as Map?)?['activeIndex'] as int? ?? 0;
    if (bg.length != math.min(2, (m['dataIds'] as List).length - index - 1)) {
      lf.add('background coverage missing');
    }
    for (var i = 0; i < bg.length; i++) {
      final distance = i + 1, c = bg[i], r = c['bounds'] as Map;
      n(
        r['width'],
        (screen['width'] as num) - (distance == 1 ? 64 : 96),
        'back$distance width',
      );
      n(r['height'], distance == 1 ? 449 : 403, 'back$distance height');
      n(
        (r['top'] as num) - (m['safeTop'] as num),
        distance == 1 ? 251 : 305,
        'back$distance top',
      );
      final sh = c['surface']['shadows'] as List;
      if (sh.isEmpty ||
          sh.first['color'] != '0x29000000' ||
          !near(sh.first['blur'], 16)) {
        lf.add('back$distance shadow');
      }
    }
  }
  return {
    'stylePassed': sf.isEmpty,
    'layoutPassed': lf.isEmpty,
    'assetPassed': af.isEmpty,
    'styleFailures': sf,
    'layoutFailures': lf,
    'assetFailures': af,
  };
}

final _capture = GlobalKey();
final _direct = GlobalKey<_DirectState>();
late Directory _output;
String _kind = 'stack', _mode = 'direct';
Set<String> _loadedCategoryIds = <String>{};
int _count = 5, _epoch = 0, _pointer = 95000;
bool _busy = false, _directDone = false, _rootDone = false;
final _errors = <String>[],
    _checks = <Map<String, Object?>>[],
    _rootChecks = <Map<String, Object?>>[];
final _clock = Stopwatch()..start();
Duration _last = Duration.zero;
Duration _time() {
  final t = _clock.elapsed;
  return _last = t > _last ? t : _last + const Duration(microseconds: 1);
}

class _DirectHost extends StatefulWidget {
  const _DirectHost({super.key, required this.count});
  final int count;
  @override
  State<_DirectHost> createState() => _DirectState();
}

class _DirectState extends State<_DirectHost> {
  final opened = <String>[], bookmarks = <String>[], bookmarked = <String>{};
  int exits = 0;
  late final data = reviewContents(count: widget.count, figmaExample: true);
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: reviewTheme(),
    scrollBehavior: const AppScrollBehavior(),
    home: PhoneFrame(
      child: CategoryCardReviewScreen(
        contents: data,
        categoryName: '취업준비',
        bookmarkedIds: bookmarked,
        onExit: () => exits++,
        onOpenContent: (c) => opened.add(c.id),
        onToggleBookmark: (c) => setState(() {
          bookmarks.add(c.id);
          if (!bookmarked.add(c.id)) bookmarked.remove(c.id);
        }),
      ),
    ),
  );
}

class ReviewRootServer {
  ReviewRootServer() {
    final c = e01.archiveAllCategoryMaps.first;
    base.records.removeRange(5, base.records.length);
    for (var i = 0; i < base.records.length; i++) {
      base.records[i] = {
        ...base.records[i],
        'categories': [c],
      };
    }
  }
  final base = e01.ArchiveAllServer();
  final bookmarkRequests = <int>[];
  bool failBookmark = false;
  late final client = MockClient((r) async {
    final m = RegExp(r'/contents/(\d+)/favorite$').firstMatch(r.url.path);
    if (m != null && r.method == 'PUT') {
      bookmarkRequests.add(int.parse(m[1]!));
      if (failBookmark) {
        failBookmark = false;
        return base.json({'detail': '다시보기 북마크 대역 실패'}, 503);
      }
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return http.Response.fromStream(await base.client.send(copy));
  });
}

ReviewRootServer _server = ReviewRootServer();
Element get _root => _capture.currentContext! as Element;
Element get _screen => _find<CategoryCardReviewScreen>(_root)!;
void _require(bool value, String why) {
  if (!value) throw StateError(why);
}

Future<void> _settle([int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    WidgetsBinding.instance.ensureVisualUpdate();
    await WidgetsBinding.instance.endOfFrame.timeout(
      const Duration(seconds: 15),
    );
  }
}

Future<void> _wait(bool Function() p, String why) async {
  for (var i = 0; i < 100; i++) {
    if (p()) return;
    await _settle(2);
  }
  throw StateError(why);
}

Future<void> _tap(Element e) async {
  final id = ++_pointer, v = View.of(_root), p = _box(e).center;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      viewId: v.viewId,
      position: p,
      timeStamp: _time(),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 70));
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: v.viewId,
      position: p,
      timeStamp: _time(),
    ),
  );
  await _settle();
}

Future<void> _drag({
  Offset delta = const Offset(0, -130),
  int steps = 8,
  int milliseconds = 45,
}) async {
  final slide = _find<AnimatedSlide>(_screen)!;
  final r = _box(slide), clip = _box(_find<ClipRect>(_screen)!);
  final start = Offset(r.center.dx, math.min(r.center.dy, clip.bottom - 40)),
      v = View.of(_root),
      id = ++_pointer;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(
      pointer: id,
      viewId: v.viewId,
      position: start,
      timeStamp: _time(),
    ),
  );
  for (var i = 1; i <= steps; i++) {
    await Future<void>.delayed(Duration(milliseconds: milliseconds));
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: id,
        viewId: v.viewId,
        position: start + delta * (i / steps),
        delta: delta / steps.toDouble(),
        timeStamp: _time(),
      ),
    );
  }
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(
      pointer: id,
      viewId: v.viewId,
      position: start + delta,
      timeStamp: _time(),
    ),
  );
  await _settle(12);
}

String _route() => _find<DetailScreen>(_root) != null
    ? 'root-detail'
    : _find<CategoryCardReviewScreen>(_root) != null
    ? (_mode == 'direct' ? 'direct-review' : 'root-review')
    : _find<ArchiveScreen>(_root) != null
    ? 'root-archive'
    : _find<HomeScreen>(_root) != null
    ? 'root-home'
    : 'other';
Future<void> _freshDirect(String kind, int count) async {
  _mode = 'direct';
  _kind = kind;
  _count = count;
  runApp(const SizedBox.shrink());
  await _settle(2);
  runApp(
    RepaintBoundary(
      key: _capture,
      child: _DirectHost(key: _direct, count: count),
    ),
  );
  await _settle(5);
  if (kind == 'complete') {
    _require(count > 0, 'Complete needs real cards');
    for (var i = 0; i < count; i++) {
      await _drag();
    }
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await _settle(3);
}

Map<String, Object?> _snapshot() {
  final m = reviewMeasure(_root),
      v = View.of(_root),
      share = e01.archiveAllShareMessenger;
  return {
    'phase': reviewPhase,
    'platform': Platform.operatingSystem,
    'kind': _kind,
    'count': _count,
    'mode': _mode,
    'route': _route(),
    'ready': true,
    'busy': _busy,
    'output': _output.path,
    'logicalSize': '${v.physicalSize / v.devicePixelRatio}',
    'pixelRatio': v.devicePixelRatio,
    'viewPaddingTop': v.viewPadding.top / v.devicePixelRatio,
    'viewPaddingBottom': v.viewPadding.bottom / v.devicePixelRatio,
    'viewInsetsBottom': v.viewInsets.bottom / v.devicePixelRatio,
    'textScale': 1.0,
    'scrollOffset': 0.0,
    ...m,
    ...reviewJudgment(m),
    'frameworkErrors': List<String>.from(_errors),
    'callbackCounts': _mode == 'direct'
        ? {
            'open': _direct.currentState?.opened,
            'bookmark': _direct.currentState?.bookmarks,
            'exit': _direct.currentState?.exits,
          }
        : null,
    'nativeShareIsolation': {
      'installed': identical(
        ServicesBinding.instance.defaultBinaryMessenger,
        share,
      ),
      'nativeDelegationCount': share?.nativeDelegationCount,
      'unknownMethods': share?.unknownShareMethods ?? <String>[],
      'argumentsOrCredentialsRecorded': false,
    },
    'requests': List<Map<String, Object?>>.from(_server.base.requests),
    'bookmarkRequests': List<int>.from(_server.bookmarkRequests),
    'unexpectedRequests': List<String>.from(_server.base.unexpected),
    'rootScope':
        'Actual root/memory integration is separate from fixed-order direct-screen screenshots. Shuffle/return index0 are existing behavior; no OAuth, production, physical-device or CI proof.',
  };
}

void _record(
  String name, {
  bool root = false,
  Map<String, Object?> fields = const {},
}) {
  (root ? _rootChecks : _checks).add({
    'scenario': name,
    'passed': true,
    ..._snapshot(),
    ...fields,
  });
}

Map<String, Object?> _flags(List<Map<String, Object?>> checks, bool done) {
  final style = !checks.any((c) => c['stylePassed'] == false),
      layout =
          _errors.isEmpty && !checks.any((c) => c['layoutPassed'] == false),
      asset = !checks.any((c) => c['assetPassed'] == false);
  final behavior = done && !checks.any((c) => c['passed'] == false);
  return {
    'checksCompleted': done,
    'coveragePassed': done,
    'stylePassed': style,
    'layoutPassed': layout,
    'assetPassed': asset,
    'behaviorPassed': behavior,
    'passed': done && style && layout && asset && behavior,
    'checks': checks,
  };
}

Future<void> _report() async {
  final direct = _flags(_checks, _directDone),
      root = _flags(_rootChecks, _rootDone),
      s = _snapshot();
  final out = {
    ...s,
    'directPassed': direct['passed'],
    'rootPassed': root['passed'],
    'directFlags': direct,
    'rootFlags': root,
    'checksCompleted': _directDone && _rootDone,
    'coveragePassed': _directDone && _rootDone,
    'stylePassed': direct['stylePassed'] == true && root['stylePassed'] == true,
    'layoutPassed':
        direct['layoutPassed'] == true && root['layoutPassed'] == true,
    'assetPassed': direct['assetPassed'] == true && root['assetPassed'] == true,
    'behaviorPassed':
        direct['behaviorPassed'] == true && root['behaviorPassed'] == true,
    'passed':
        direct['passed'] == true && root['passed'] == true && _errors.isEmpty,
    'checks': _checks,
    'rootChecks': _rootChecks,
  };
  await File(
    '${_output.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(out));
  if (_mode == 'direct' && _directDone) {
    await File('${_output.path}/direct-report.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        ...s,
        ...direct,
        'scope':
            'Fixed direct screen with frozen order; not root routing proof.',
      }),
    );
  }
  if (_mode == 'root' && _rootDone) {
    await File('${_output.path}/root-report.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        ...s,
        ...root,
        'scope':
            'Actual root route and target-ID integration; variable existing shuffle and progress reset allowed.',
      }),
    );
  }
}

Future<void> _captureScene() async {
  await _settle(3);
  final image =
      await (_capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: View.of(_root).devicePixelRatio);
  try {
    final d = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${_output.path}/review_${_kind}_count_${_count}_scale_1.png',
    ).writeAsBytes(d!.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
  } finally {
    image.dispose();
  }
  _record('static_$_kind');
}

Future<void> _directRun() async {
  _checks.clear();
  _directDone = false;
  await _freshDirect('stack', 5);
  _record('direct_initial');
  final state = _direct.currentState!,
      front = _find<AnimatedSlide>(_screen)!,
      card = _find<CategoryReviewCard>(front)!;
  final id = (card.widget as CategoryReviewCard).content.id;
  final bookmark =
      _key(card, 'review-bookmark-$id') ??
      _elements(card).firstWhere(
        (e) =>
            e.widget is InkWell &&
            (e.widget as InkWell).customBorder is CircleBorder,
      );
  await _tap(bookmark);
  _require(
    state.bookmarks.length == 1 && state.opened.isEmpty,
    'Bookmark must not open card',
  );
  _record('direct_bookmark');
  await _tap(
    _text(
      _find<CategoryReviewCard>(_find<AnimatedSlide>(_screen)!)!,
      (card.widget as CategoryReviewCard).content.title,
    )!,
  );
  _require(state.opened.length == 1, 'Card callback once');
  _record('direct_open');
  await _drag(delta: const Offset(0, 35), milliseconds: 110);
  _require(
    (_find<CardPagerProgress>(_screen)!.widget as CardPagerProgress)
            .activeIndex ==
        0,
    'Small drag must return',
  );
  _record('direct_snapback');
  for (var i = 0; i < 5; i++) {
    await _drag();
    if (i < 4) {
      _require(
        (_find<CardPagerProgress>(_screen)!.widget as CardPagerProgress)
                .activeIndex ==
            i + 1,
        'Advance index',
      );
    }
    _record('direct_advance_${i + 1}');
  }
  _kind = 'complete';
  _require(_find<AnimatedSlide>(_screen) == null, 'Last card not exhausted');
  _record('direct_complete');
  await _tap(_text(_screen, '나가기')!);
  _require(state.exits == 1, 'Complete exit callback missing');
  _record('direct_complete_exit');
  await _freshDirect('stack', 0);
  _require(
    (_screen.widget as CategoryCardReviewScreen).contents.isEmpty,
    'Empty input lost',
  );
  _record('direct_empty');
  await _tap(_text(_screen, '나가기')!);
  _require(_direct.currentState!.exits == 1, 'Empty exit missing');
  _record('direct_empty_exit');
  await _freshDirect('stack', 5);
  _record('final_direct_stack');
  _directDone = true;
}

Future<void> _visible(Element e) async {
  await Scrollable.ensureVisible(
    e,
    duration: const Duration(milliseconds: 150),
    alignment: .5,
  );
  await _settle(4);
}

Future<void> _freshRoot() async {
  _mode = 'root';
  _kind = 'root';
  _count = 5;
  _server = ReviewRootServer();
  runApp(const SizedBox.shrink());
  await _settle(2);
  runApp(
    RepaintBoundary(
      key: _capture,
      child: ClipbackApp(
        key: ValueKey(++_epoch),
        sessionStorage: e01.ArchiveAllMemoryStorage(),
        socialAuth: e01.ArchiveAllSocialAuth(),
      ),
    ),
  );
  // runApp attaches the new root on the next frame after the old keyed
  // capture host has been disposed. Do not dereference its context earlier.
  await _settle(2);
  await _wait(() => _find<HomeScreen>(_root) != null, 'Root home missing');
  await _tap(_text(_find<ClipbackNavigationBar>(_root)!, '아카이브')!);
  await _wait(
    () => _find<ArchiveScreen>(_root) != null,
    'Root archive missing',
  );
  await _tap(_text(_find<ArchiveTabs>(_root)!, '카테고리')!);
  await _wait(
    () => _elements(_root).any(
      (e) =>
          e.widget is CategoryRow &&
          (e.widget as CategoryRow).category.id == 101,
    ),
    'Category row missing',
  );
  final row = _elements(_root).firstWhere(
    (e) =>
        e.widget is CategoryRow && (e.widget as CategoryRow).category.id == 101,
  );
  await _visible(row);
  await _tap(row);
  await _wait(
    () => _find<RandomReviewButton>(_root) != null,
    'Random review entry missing',
  );
  final archive = _find<ArchiveScreen>(_root)!.widget as ArchiveScreen;
  _loadedCategoryIds = archive.contents
      .where((c) => c.categories.any((v) => v.id == 101))
      .map((c) => c.id)
      .toSet();
  await _tap(_find<RandomReviewButton>(_root)!);
  await _wait(() => _route() == 'root-review', 'Actual review route missing');
  await _settle(10);
}

ContentItem _frontContent() =>
    (_find<CategoryReviewCard>(_find<AnimatedSlide>(_screen)!)!.widget
            as CategoryReviewCard)
        .content;
Future<void> _rootRun() async {
  _rootChecks.clear();
  _rootDone = false;
  await _freshRoot();
  final allowed = _server.base.records
      .where(
        (r) => (r['categories'] as List).any((c) => (c as Map)['id'] == 101),
      )
      .map((r) => 'api-${r['id']}')
      .toSet()
      .intersection(_loadedCategoryIds);
  final selected = (_screen.widget as CategoryCardReviewScreen).contents;
  _require(
    selected.length == math.min(5, _loadedCategoryIds.length) &&
        selected.map((c) => c.id).toSet().length == selected.length,
    'Selection count/unique IDs differ from actual loaded category',
  );
  _require(
    ((_screen.widget as CategoryCardReviewScreen).contents
            .map((c) => c.id)
            .toSet())
        .difference(allowed)
        .isEmpty,
    'Selected IDs leave actual loaded category',
  );
  _record(
    'root_category_review_enter',
    root: true,
    fields: {
      'loadedCategoryIds': _loadedCategoryIds.toList()..sort(),
      'selectionOrder': (_screen.widget as CategoryCardReviewScreen).contents
          .map((c) => c.id)
          .toList(),
      'selectedId': _frontContent().id,
    },
  );
  final target = _frontContent(),
      initial = (_screen.widget as CategoryCardReviewScreen).bookmarkedIds
          .contains(target.id);
  _server.failBookmark = true;
  var front = _find<CategoryReviewCard>(_find<AnimatedSlide>(_screen)!)!;
  Element bookmark(Element card, String id) =>
      _key(card, 'review-bookmark-$id') ??
      _elements(card).firstWhere(
        (e) =>
            e.widget is InkWell &&
            (e.widget as InkWell).customBorder is CircleBorder,
      );
  await _tap(bookmark(front, target.id));
  await _wait(
    () =>
        _server.bookmarkRequests.length == 1 &&
        (_screen.widget as CategoryCardReviewScreen).contents.every(
          (c) => c.mutationLabel == null,
        ),
    'Failed mutation did not settle',
  );
  _require(
    _server.bookmarkRequests.single == target.apiId,
    'Failure requested another ID',
  );
  _require(
    (_screen.widget as CategoryCardReviewScreen).bookmarkedIds.contains(
          target.id,
        ) ==
        initial,
    'Failed mutation did not restore target',
  );
  _record(
    'root_bookmark_failure_restored',
    root: true,
    fields: {
      'targetId': target.id,
      'selectionOrder': (_screen.widget as CategoryCardReviewScreen).contents
          .map((c) => c.id)
          .toList(),
    },
  );
  ScaffoldMessenger.of(_screen).hideCurrentSnackBar();
  await _settle(6);
  for (
    var i = 0;
    i < 5 &&
        _find<AnimatedSlide>(_screen) != null &&
        _frontContent().id != target.id;
    i++
  ) {
    await _drag();
  }
  _require(
    _find<AnimatedSlide>(_screen) != null && _frontContent().id == target.id,
    'Retry target not reachable in shuffled selection',
  );
  front = _find<CategoryReviewCard>(_find<AnimatedSlide>(_screen)!)!;
  await _tap(bookmark(front, target.id));
  await _wait(
    () =>
        _server.bookmarkRequests.length == 2 &&
        (_screen.widget as CategoryCardReviewScreen).contents.every(
          (c) => c.mutationLabel == null,
        ),
    'Retry did not settle',
  );
  _require(
    _server.bookmarkRequests.last == target.apiId,
    'Retry changed target ID',
  );
  _require(
    (_screen.widget as CategoryCardReviewScreen).bookmarkedIds.contains(
          target.id,
        ) !=
        initial,
    'Retry did not persist memory favorite',
  );
  _record(
    'root_bookmark_retry_success',
    root: true,
    fields: {
      'targetId': target.id,
      'selectionOrder': (_screen.widget as CategoryCardReviewScreen).contents
          .map((c) => c.id)
          .toList(),
    },
  );
  final open = _frontContent();
  await _tap(
    _text(
      _find<CategoryReviewCard>(_find<AnimatedSlide>(_screen)!)!,
      open.title,
    )!,
  );
  await _wait(() => _find<DetailScreen>(_root) != null, 'Root detail missing');
  _require(
    (_find<DetailScreen>(_root)!.widget as DetailScreen).content.id == open.id,
    'Detail opened other ID',
  );
  _record('root_detail_target', root: true, fields: {'targetId': open.id});
  await _tap(_key(_root, 'detail-back')!);
  await _wait(
    () => _route() == 'root-review',
    'Detail return did not restore review route',
  );
  await _settle(10);
  _require(
    (_find<CardPagerProgress>(_screen)!.widget as CardPagerProgress)
            .activeIndex ==
        0,
    'Existing detail return should start at index0',
  );
  _record(
    'root_detail_return_index_zero',
    root: true,
    fields: {
      'selectionOrder': (_screen.widget as CategoryCardReviewScreen).contents
          .map((c) => c.id)
          .toList(),
      'existingShuffleAndResetAllowed': true,
    },
  );
  await _tap(_text(_screen, '나가기')!);
  await _wait(
    () => _route() == 'root-archive',
    'Exit did not return category archive',
  );
  final archive = _find<ArchiveScreen>(_root)!.widget as ArchiveScreen;
  _require(
    archive.activeCategoryName == '일상' && !archive.randomViewing,
    'Exit changed selected category',
  );
  _record('root_exit_same_category', root: true);
  await _tap(_find<RandomReviewButton>(_root)!);
  await _wait(() => _route() == 'root-review', 'Review reentry missing');
  await _settle(10);
  _require(
    _server.base.records.length == 5 && _server.base.unexpected.isEmpty,
    'Unexpected server mutation/request',
  );
  _require(
    (_find<CardPagerProgress>(_screen)!.widget as CardPagerProgress)
            .activeIndex ==
        0,
    'Final root index mismatch',
  );
  _record(
    'final_root_review_index_zero',
    root: true,
    fields: {
      'selectionOrder': (_screen.widget as CategoryCardReviewScreen).contents
          .map((c) => c.id)
          .toList(),
      'selectedId': _frontContent().id,
    },
  );
  _rootDone = true;
}

Future<void> main() => http.runWithClient(() async {
  e01.ArchiveAllFixtureBinding();
  _output = await Directory.systemTemp.createTemp(
    'clipback-card-review-alignment-',
  );
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    _errors.add(d.exceptionAsString());
    old?.call(d);
  };
  await _freshDirect('stack', 5);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8767);
  debugPrint(
    'CARD_REVIEW_ALIGNMENT ready phase=$reviewPhase output=${_output.path}',
  );
  await for (final request in server) {
    final read = ['/ready', '/state', '/status'].contains(request.uri.path);
    if (_busy && !read) {
      request.response.statusCode = 409;
      await request.response.close();
      continue;
    }
    if (!read) _busy = true;
    try {
      switch (request.uri.path) {
        case '/ready':
        case '/state':
        case '/status':
          break;
        case '/scene':
          final kind = request.uri.queryParameters['kind'] ?? 'stack',
              count = int.parse(request.uri.queryParameters['count'] ?? '5');
          _require(['stack', 'complete'].contains(kind), 'Unknown scene');
          await _freshDirect(kind, count);
          await _captureScene();
        case '/run':
          await _directRun();
        case '/root-run':
          await _rootRun();
        default:
          request.response.statusCode = 404;
      }
      await _report();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        await File('${_output.path}/report.json').readAsString(),
      );
    } catch (error, stack) {
      (_mode == 'root' ? _rootChecks : _checks).add({
        'scenario': 'request_failure',
        'passed': false,
        'error': '$error',
      });
      debugPrint('REVIEW FAIL $error\n$stack');
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      try {
        await _report();
        final report =
            jsonDecode(await File('${_output.path}/report.json').readAsString())
                as Map<String, dynamic>;
        request.response.write(jsonEncode({...report, 'error': '$error'}));
      } catch (reportError) {
        // A failed root attachment can make render measurements unavailable.
        // Preserve an explicit failed JSON result instead of throwing again
        // from _snapshot and returning an empty HTTP body.
        final fallback = {
          'phase': reviewPhase,
          'platform': Platform.operatingSystem,
          'kind': _kind,
          'mode': _mode,
          'output': _output.path,
          'ready': false,
          'active': false,
          'route': 'unavailable',
          'error': '$error',
          'reportError': '$reportError',
          'checksCompleted': false,
          'coveragePassed': false,
          'stylePassed': false,
          'layoutPassed': false,
          'assetPassed': false,
          'behaviorPassed': false,
          'passed': false,
          'frameworkErrors': List<String>.from(_errors),
          'checks': _checks,
          'rootChecks': _rootChecks,
        };
        final encoded = const JsonEncoder.withIndent('  ').convert(fallback);
        await File('${_output.path}/report.json').writeAsString(encoded);
        request.response.write(encoded);
      }
    } finally {
      if (!read) _busy = false;
      await request.response.close();
    }
  }
}, () => _server.client);
