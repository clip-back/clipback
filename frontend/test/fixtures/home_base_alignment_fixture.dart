// C01/C02 render oracle and in-memory HTTP. Imported by both widget checks and
// the actual-root native preview; target failures never prevent BEFORE capture.
import 'dart:async';
import 'dart:convert';
import 'package:clipback_frontend/features/home/home_screen.dart';
import 'package:clipback_frontend/shared/content/bookmark_button.dart';
import 'package:clipback_frontend/shared/category/category_widgets.dart';
import 'package:clipback_frontend/shared/widgets/section_header.dart';
import 'package:flutter/services.dart';
import 'package:clipback_frontend/shared/models/content_item.dart';
import 'package:clipback_frontend/shared/models/feed_page.dart';
import 'package:clipback_frontend/shared/widgets/buttons.dart';
import 'package:clipback_frontend/shared/widgets/icons.dart';
import 'package:clipback_frontend/shared/widgets/page_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../fixtures/logout_alignment_fixture.dart' as common;
import '../support/archive_all_preview.dart' as archive;

const homeBaseLogo = 'assets/figma/home-logo.svg';
const homeBaseOutline = 'assets/figma/home-bookmark-outline.svg';
List<Element> homeBaseElements(Element root) => common.logoutElements(root);
Element? homeBaseFind<T extends Widget>(Element root) =>
    common.logoutFind<T>(root);
Element? homeBaseText(Element root, String text) =>
    common.logoutText(root, text);
Rect homeBaseBox(Element root) => common.logoutBox(root);
Map<String, double> homeBaseRect(Rect rect) => common.logoutRect(rect);
Element? homeBaseAncestor(Element e, bool Function(Widget) yes) {
  Element? result;
  e.visitAncestorElements((a) {
    if (yes(a.widget)) {
      result = a;
      return false;
    }
    return true;
  });
  return result;
}

String? _color(Color? c) => c == null
    ? null
    : '0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
Map<String, Object?> _paragraph(Element? element) {
  if (element == null) return {};
  final e = element.widget is RichText
      ? element
      : homeBaseFind<RichText>(element);
  if (e == null) return {};
  final p = e.findRenderObject()! as RenderParagraph,
      s = (p.text as TextSpan).style!;
  final spans = <Map<String, Object?>>[];
  void visit(InlineSpan span, TextStyle inherited) {
    if (span is! TextSpan) return;
    final merged = inherited.merge(span.style);
    if (span.text case final text?) {
      if (text.isNotEmpty) {
        spans.add({
          'text': text,
          'color': _color(merged.color),
          'fontSize': merged.fontSize,
          'fontWeight': merged.fontWeight?.value,
        });
      }
    }
    for (final child in span.children ?? <InlineSpan>[]) {
      visit(child, merged);
    }
  }

  visit(p.text, const TextStyle());
  return {
    'text': p.text.toPlainText(),
    'bounds': homeBaseRect(homeBaseBox(e)),
    'fontFamily': s.fontFamily,
    'fontSize': s.fontSize,
    'fontWeight': s.fontWeight?.value,
    'letterSpacing': s.letterSpacing,
    'height': s.height,
    'color': _color(s.color),
    'scaledFontSize': s.fontSize == null
        ? null
        : p.textScaler.scale(s.fontSize!),
    'maxLines': p.maxLines,
    'overflow': p.overflow.name,
    'didExceedMaxLines': p.didExceedMaxLines,
    'spans': spans,
  };
}

Map<String, Object?> _asset(Element? e) {
  if (e == null) return {};
  final svg = e.widget is SvgPicture ? e : homeBaseFind<SvgPicture>(e);
  if (svg != null) {
    final w = svg.widget as SvgPicture;
    final icon = homeBaseAncestor(svg, (w) => w is SvgIcon)?.widget as SvgIcon?;
    return {
      'asset': w.bytesLoader is SvgAssetLoader
          ? (w.bytesLoader as SvgAssetLoader).assetName
          : null,
      'bounds': homeBaseRect(homeBaseBox(svg)),
      'unfiltered': w.colorFilter == null,
      'iconColor': _color(icon?.color),
    };
  }
  final image = e.widget is Image ? e : homeBaseFind<Image>(e);
  if (image == null) return {};
  final w = image.widget as Image;
  ImageProvider p = w.image;
  if (p is ResizeImage) p = p.imageProvider;
  return {
    'asset': p is AssetImage ? p.assetName : null,
    'bounds': homeBaseRect(homeBaseBox(image)),
    'fit': w.fit?.name,
  };
}

Element? homeBaseRecentRail(Element root) {
  final card = homeBaseFind<HomeContentCard>(root);
  return card == null
      ? null
      : homeBaseAncestor(
          card,
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        );
}

ScrollPosition? homeBasePosition(Element root, {bool recent = false}) {
  final screen = homeBaseFind<HomeScreen>(root);
  if (screen == null) return null;
  final scope = recent ? homeBaseRecentRail(screen) : screen;
  if (scope == null) return null;
  final e = homeBaseFind<Scrollable>(scope);
  return e is StatefulElement && e.state is ScrollableState
      ? (e.state as ScrollableState).position
      : null;
}

Map<String, Object?> _feed(FeedPage? f) => {
  'present': f != null,
  'initialized': f?.initialized,
  'loading': f?.loading,
  'error': f?.error?.toString(),
  'query': f?.query,
  'categoryId': f?.categoryId,
  'isFavorite': f?.isFavorite,
  'hasMore': f?.hasMore,
  'nextCursor': f?.nextCursor,
  'version': f?.version,
  'itemIds': f?.items.map((v) => v.id).toList(),
};
Map<String, Object?> homeBaseMeasure(Element root) {
  final screen = homeBaseFind<HomeScreen>(root);
  if (screen == null) return {'active': false};
  final w = screen.widget as HomeScreen,
      hero = homeBaseFind<HomeHero>(screen)!,
      panel = homeBaseFind<HomeContentPanel>(screen)!;
  final header =
      common.logoutKey(hero, 'home-header') ??
      homeBaseElements(hero)
          .where(
            (e) => e.widget is SizedBox && (e.widget as SizedBox).height == 56,
          )
          .first;
  final media = MediaQuery.of(screen), frame = homeBaseFind<Scaffold>(screen)!;
  final heroW = hero.widget as HomeHero;
  final title = homeBaseText(
    hero,
    heroW.hasSavedContent
        ? '나중에 보려던 것들,'
        : heroW.confirmedEmpty
        ? '아직 저장한 콘텐츠가 없어요.'
        : '저장한 정보가 없어요.',
  );
  final subtitle = homeBaseText(
    hero,
    heroW.hasSavedContent
        ? '지금 하나만 꺼내볼까요?'
        : heroW.confirmedEmpty
        ? '지금 하나만 저장해볼까요?'
        : '지금 하나만 저장할까요?',
  );
  final svgs = homeBaseElements(
    header,
  ).where((e) => e.widget is SvgPicture).toList();
  final icons = homeBaseElements(
    header,
  ).where((e) => e.widget is SvgIconButton).toList();
  final picks = <Map<String, Object?>>[];
  final weekly = homeBaseFind<WeeklyPickRail>(screen);
  if (weekly != null) {
    for (final e in homeBaseElements(weekly).where(
      (e) =>
          e.widget is Container &&
          (e.widget as Container).constraints?.maxWidth == 133,
    )) {
      final c = e.widget as Container, column = homeBaseFind<Column>(e)!;
      final texts = homeBaseElements(
        e,
      ).where((e) => e.widget is RichText).toList();
      final d = c.decoration as BoxDecoration;
      picks.add({
        'bounds': homeBaseRect(homeBaseBox(e)),
        'column': homeBaseRect(homeBaseBox(column)),
        'label': _paragraph(texts.first),
        'title': _paragraph(texts.last),
        'fill': _color(d.color),
        'radius': (d.borderRadius as BorderRadius?)?.topLeft.x,
        'borderWidth': d.border is Border ? (d.border as Border).top.width : 0,
      });
    }
  }
  final cards = <Map<String, Object?>>[];
  for (final e in homeBaseElements(
    screen,
  ).where((e) => e.widget is HomeContentCard)) {
    final c = e.widget as HomeContentCard,
        column = homeBaseFind<Column>(e)!,
        star = homeBaseFind<BookmarkActionButton>(e)!;
    cards.add({
      'id': c.content.id,
      'bounds': homeBaseRect(homeBaseBox(e)),
      'column': homeBaseRect(homeBaseBox(column)),
      'title': _paragraph(homeBaseText(e, c.content.title)),
      'summary': _paragraph(homeBaseText(e, c.content.summary)),
      'category': _paragraph(homeBaseText(e, c.content.category.name)),
      'categoryColor': _color(c.content.category.deep),
      'bookmark': {
        'bounds': homeBaseRect(homeBaseBox(star)),
        'asset': _asset(star),
        'active': c.bookmarked,
        'enabled': (star.widget as BookmarkActionButton).enabled,
      },
      'mutationLabel': c.content.mutationLabel,
    });
  }
  final sections = <Map<String, Object?>>[];
  for (final e in homeBaseElements(
    screen,
  ).where((e) => e.widget is SectionHeader)) {
    final w = e.widget as SectionHeader;
    sections.add({
      'title': w.title,
      'showTrailingIcon': w.showTrailingIcon,
      'bounds': homeBaseRect(homeBaseBox(e)),
      'style': _paragraph(homeBaseText(e, w.title)),
    });
  }
  final chips = <Map<String, Object?>>[];
  final chipElement = homeBaseFind<CategoryChips>(screen);
  if (chipElement != null) {
    final w = chipElement.widget as CategoryChips;
    for (final label in w.categories) {
      final e = homeBaseText(chipElement, label);
      if (e == null) continue;
      final box = homeBaseAncestor(e, (w) => w is SizedBox && w.width == 70)!;
      final material =
          homeBaseAncestor(e, (w) => w is Material)!.widget as Material;
      chips.add({
        'label': label,
        'active': label == w.activeLabel,
        'bounds': homeBaseRect(homeBaseBox(box)),
        'style': _paragraph(e),
        'fill': _color(material.color),
      });
    }
  }
  final dotItems = <Map<String, Object?>>[];
  final dotsElement = homeBaseFind<PageDots>(screen);
  if (dotsElement != null) {
    for (final e in homeBaseElements(
      dotsElement,
    ).where((e) => e.widget is AnimatedContainer)) {
      final w = e.widget as AnimatedContainer,
          painted = homeBaseFind<DecoratedBox>(e)!;
      final d = (painted.widget as DecoratedBox).decoration as BoxDecoration;
      dotItems.add({
        'bounds': homeBaseRect(homeBaseBox(painted)),
        'color': _color(d.color),
        'durationMs': w.duration.inMilliseconds,
      });
    }
  }
  final dots = homeBaseFind<PageDots>(screen)?.widget as PageDots?;
  final empty = homeBaseFind<EmptyHomeContent>(screen);
  final body = homeBaseFind<SingleChildScrollView>(screen)!;
  return {
    'active': true,
    'bounds': {
      'screen': homeBaseRect(homeBaseBox(frame)),
      'hero': homeBaseRect(homeBaseBox(hero)),
      'header': homeBaseRect(homeBaseBox(header)),
      'body': homeBaseRect(homeBaseBox(body)),
      'panel': homeBaseRect(homeBaseBox(panel)),
    },
    'hero': {
      'hasSavedContent': heroW.hasSavedContent,
      'confirmedEmpty': heroW.confirmedEmpty,
      'title': _paragraph(title),
      'subtitle': _paragraph(subtitle),
      'character': _asset(homeBaseFind<Image>(hero)),
    },
    'header': {
      'logo': _asset(svgs.isEmpty ? null : svgs.first),
      'icons': [
        for (final e in icons)
          {'bounds': homeBaseRect(homeBaseBox(e)), 'asset': _asset(e)},
      ],
    },
    'sections': sections,
    'chips': chips,
    'picks': picks,
    'cards': cards,
    'dots': {
      'count': dots?.count,
      'activeIndex': dots?.activeIndex,
      'items': dotItems,
    },
    'empty': empty == null
        ? null
        : {
            'confirmedEmpty': (empty.widget as EmptyHomeContent).confirmedEmpty,
            'bounds': homeBaseRect(homeBaseBox(empty)),
            'title': _paragraph(homeBaseText(empty, '저장한 콘텐츠가 없어요')),
            'body': _paragraph(
              homeBaseText(empty, 'SNS에서 발견한 유용한 게시물을 저장하면 이곳에서 다시 확인할 수 있어요.'),
            ),
            'image': _asset(homeBaseFind<Image>(empty)),
            'imageSlot': homeBaseRect(
              homeBaseBox(
                homeBaseElements(empty)
                        .where(
                          (e) =>
                              e.widget is SizedBox &&
                              (e.widget as SizedBox).width == 67 &&
                              (e.widget as SizedBox).height == 78,
                        )
                        .firstOrNull ??
                    homeBaseFind<Image>(empty)!,
              ),
            ),
          },
    'feed': _feed(w.feed),
    'displayIds': w.contents.map((c) => c.id).toList(),
    'activeCategoryId': w.activeCategoryId,
    'topSafeArea': media.viewPadding.top,
    'bottomSafeArea': media.viewPadding.bottom,
    'textScale': media.textScaler.scale(1),
    'scrollOffset': homeBasePosition(root)?.pixels ?? 0,
    'maxScrollExtent': homeBasePosition(root)?.maxScrollExtent ?? 0,
    'recentOffset': homeBasePosition(root, recent: true)?.pixels ?? 0,
    'recentMaxScrollExtent':
        homeBasePosition(root, recent: true)?.maxScrollExtent ?? 0,
  };
}

Map<String, Object?> homeBaseJudgment(Map<String, Object?> m) {
  final sf = <String>[], lf = <String>[], af = <String>[];
  if (m['active'] != true) {
    return {
      'stylePassed': true,
      'layoutPassed': true,
      'assetPassed': true,
      'styleFailures': sf,
      'layoutFailures': lf,
      'assetFailures': af,
    };
  }
  bool near(Object? a, num b) => a is num && (a - b).abs() < .18;
  void n(Object? x, num y, String why) {
    if (!near(x, y)) lf.add('$why: $x != $y');
  }

  void style(
    Map p,
    num size,
    int weight,
    num tracking,
    String color,
    String why, {
    double? height,
  }) {
    if (p['fontFamily'] != 'Pretendard' ||
        !near(p['fontSize'], size) ||
        !near(p['scaledFontSize'], size) ||
        p['fontWeight'] != weight ||
        !near(p['letterSpacing'], tracking) ||
        p['color'] != color ||
        (height == null ? p['height'] != null : !near(p['height'], height))) {
      sf.add('$why: $p');
    }
  }

  final b = m['bounds'] as Map,
      header = m['header'] as Map,
      hero = m['hero'] as Map,
      screen = b['screen'] as Map,
      h = b['header'] as Map;
  n(h['height'], 56, 'header inner56');
  if (near(m['scrollOffset'], 0)) {
    n(h['top'], (m['topSafeArea'] as num) + 8, 'header top8');
  }
  final logo = header['logo'] as Map, lb = logo['bounds'] as Map;
  if (logo['asset'] != homeBaseLogo || logo['unfiltered'] != true) {
    af.add('Exact home logo');
  }
  n(lb['width'], 71.41, 'logo width');
  n(lb['height'], 24, 'logo height');
  n((lb['left'] as num) - (screen['left'] as num), 16, 'logo left');
  n((lb['top'] as num) + 12, (h['top'] as num) + 28.5, 'logo center+.5');
  final icons = header['icons'] as List;
  if (icons.length != 2) {
    lf.add('Expected search and bell');
  } else {
    for (var i = 0; i < 2; i++) {
      final icon = icons[i] as Map,
          a = icon['asset'] as Map,
          ir = icon['bounds'] as Map,
          ar = a['bounds'] as Map;
      n(ir['width'], 24, 'header hit24');
      n(ir['height'], 24, 'header hit24');
      n(ar['width'], 24, 'header source24');
      n(ar['height'], 24, 'header source24');
      n(
        (ar['top'] as num) + 12,
        (h['top'] as num) + 28.5,
        'header icon center+.5',
      );
      if (a['iconColor'] != '0xFF000000' && a['unfiltered'] != true) {
        af.add('Header exact black');
      }
    }
    n(
      (icons[1]['bounds']['left'] as num) -
          (icons[0]['bounds']['right'] as num),
      16,
      'header icons gap',
    );
    n(
      (screen['right'] as num) - (icons[1]['bounds']['right'] as num),
      16,
      'bell right',
    );
  }
  if (hero['hasSavedContent'] == true || hero['confirmedEmpty'] == true) {
    style(
      hero['title'] as Map,
      20,
      600,
      -.5,
      '0xFF1A1A1A',
      'hero title',
      height: 1.6,
    );
    style(
      hero['subtitle'] as Map,
      18,
      500,
      -.45,
      '0xFF1A1A1A',
      'hero subtitle',
    );
    final chr = hero['character']['bounds'] as Map;
    n(chr['width'], 99, 'hero character99');
    n(chr['height'], 123, 'hero character123');
  }
  for (final pick in m['picks'] as List) {
    final r = pick['bounds'] as Map,
        c = pick['column'] as Map,
        p = pick['title'] as Map;
    n(r['width'], 133, 'weekly133');
    n(r['height'], 120, 'weekly120');
    n((c['left'] as num) - (r['left'] as num), 16, 'weekly L16');
    n((r['right'] as num) - (c['right'] as num), 21, 'weekly R21');
    n((c['top'] as num) - (r['top'] as num), 16, 'weekly top16');
    n((r['bottom'] as num) - (c['bottom'] as num), 16, 'weekly bottom16');
    style(pick['label'] as Map, 14, 500, -.35, '0xFF484848', 'weekly label');
    style(p, 16, 600, -.4, '0xFF1A1A1A', 'weekly title', height: 1.5);
    if (p['maxLines'] != 2 || p['overflow'] != 'ellipsis') {
      sf.add('Weekly two line ellipsis');
    }
    final accents = (p['spans'] as List)
        .where((s) => s['color'] == '0xFFFF0000')
        .map((s) => s['text'])
        .join();
    final text = p['text'] as String;
    for (final expected in ['일본 여행', '다이어트']) {
      if (text.contains(expected) && !accents.contains(expected)) {
        sf.add('Missing red $expected');
      }
    }
  }
  for (final card in m['cards'] as List) {
    final r = card['bounds'] as Map,
        c = card['column'] as Map,
        star = card['bookmark'] as Map,
        hit = star['bounds'] as Map,
        asset = star['asset'] as Map,
        ar = asset['bounds'] as Map;
    n(r['width'], 298, 'recent298');
    n(r['height'], 186, 'recent186');
    n((c['left'] as num) - (r['left'] as num), 16.5, 'recent L16.5');
    n(c['width'], 266, 'recent column266');
    n((c['top'] as num) - (r['top'] as num), 16, 'recent top16');
    n((r['right'] as num) - (c['right'] as num), 15.5, 'recent R15.5');
    style(
      card['title'] as Map,
      16,
      600,
      -.4,
      '0xFF1A1A1A',
      'recent title',
      height: 1.5,
    );
    style(
      card['summary'] as Map,
      14,
      400,
      -.35,
      '0xFF767676',
      'recent summary',
      height: 1.6,
    );
    style(
      card['category'] as Map,
      12,
      500,
      -.3,
      card['categoryColor'] as String,
      'recent category',
    );
    if (card['title']['maxLines'] != 2 || card['summary']['maxLines'] != 3) {
      sf.add('Recent line limits');
    }
    n(hit['width'], 44, 'star hit44');
    n(hit['height'], 44, 'star hit44');
    n((r['right'] as num) - (hit['right'] as num), 3.5, 'star right3.5');
    n((hit['top'] as num) - (r['top'] as num), 4, 'star top4');
    n((ar['left'] as num) - (r['left'] as num), 258.5, 'star image left258.5');
    n((ar['top'] as num) - (r['top'] as num), 12, 'star image top12');
    n(ar['width'], 28, 'star image28');
    n(ar['height'], 28, 'star image28');
    if (star['active'] != true && asset['asset'] != homeBaseOutline) {
      af.add('Home thin outline');
    }
    for (final role in ['title', 'summary']) {
      final p = card[role]['bounds'] as Map;
      if ((p['top'] as num) < (c['top'] as num) - .18 ||
          (p['bottom'] as num) > (c['bottom'] as num) + .18) {
        lf.add('Recent $role outside internal column');
      }
    }
  }
  for (final section in m['sections'] as List) {
    style(
      section['style'] as Map,
      18,
      600,
      -.45,
      '0xFF1A1A1A',
      'section title',
    );
    if ((section['bounds']['height'] as num) < 43.8) {
      lf.add('Section minimum44');
    }
    if (section['title'] == '이번주 허투루 픽 🎯' &&
        section['showTrailingIcon'] != false) {
      lf.add('Weekly arrow hidden');
    }
  }
  for (final chip in m['chips'] as List) {
    n(chip['bounds']['width'], 70, 'chip width70');
    n(chip['bounds']['height'], 32, 'chip height32');
    style(
      chip['style'] as Map,
      15,
      chip['active'] == true ? 600 : 500,
      -.375,
      chip['active'] == true ? '0xFF484848' : '0xFFD1D1D1',
      'chip role',
    );
    if (chip['active'] == true && chip['fill'] != '0xFFE4E4E4') {
      lf.add('Selected chip fill');
    }
  }
  final dots = m['dots'] as Map, dotItems = dots['items'] as List;
  final expectedCount = (m['displayIds'] as List).take(4).length;
  if (dotItems.isNotEmpty && dots['count'] != expectedCount) {
    lf.add('Dynamic dot count');
  }
  for (var i = 0; i < dotItems.length; i++) {
    final item = dotItems[i], active = i == dots['activeIndex'];
    n(item['bounds']['width'], active ? 10 : 6, 'dot width');
    n(item['bounds']['height'], 6, 'dot height');
    if (item['color'] != (active ? '0xFF1A1A1A' : '0xFFD1D1D1') ||
        item['durationMs'] != 180) {
      sf.add('Dot role/duration');
    }
    if (i > 0) {
      n(
        (item['bounds']['left'] as num) -
            (dotItems[i - 1]['bounds']['right'] as num),
        4,
        'dot gap4',
      );
    }
  }
  final empty = m['empty'] as Map?;
  if (empty != null && empty['confirmedEmpty'] == true) {
    style(empty['title'] as Map, 15, 600, -.375, '0xFF484848', 'empty title');
    style(
      empty['body'] as Map,
      14,
      500,
      -.35,
      '0xFF767676',
      'empty body',
      height: 1.6,
    );
    final slot = empty['imageSlot'] as Map,
        image = empty['image']['bounds'] as Map;
    n(slot['width'], 67, 'empty logical67');
    n(slot['height'], 78, 'empty logical78');
    n(image['width'], 71, 'empty painted71');
    n(image['height'], 82, 'empty painted82');
    n(
      (image['left'] as num) - (slot['left'] as num),
      -2,
      'empty source crop -2',
    );
    n((image['top'] as num) - (slot['top'] as num), 0, 'empty source top');
    n(
      (empty['title']['bounds']['top'] as num) - (slot['bottom'] as num),
      16,
      'empty image label16',
    );
    n(
      (empty['body']['bounds']['top'] as num) -
          (empty['title']['bounds']['bottom'] as num),
      8,
      'empty title body8',
    );
  }
  for (final entry in homeBaseSourceAssets.entries) {
    if ((entry.value as Map)['valid'] != true) {
      af.add('Exact bundled source ${entry.key}');
    }
  }
  final feed = m['feed'] as Map;
  final targetEmpty =
      (m['displayIds'] as List).isEmpty &&
      m['activeCategoryId'] == null &&
      feed['present'] == true &&
      feed['categoryId'] == null &&
      feed['query'] == null &&
      feed['isFavorite'] == null &&
      feed['initialized'] == true &&
      feed['loading'] == false &&
      feed['error'] == null &&
      feed['hasMore'] == false &&
      feed['nextCursor'] == null &&
      (feed['itemIds'] as List).isEmpty;
  if (hero['confirmedEmpty'] != targetEmpty) {
    lf.add('Strict global empty guard mismatch');
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

Map<String, Object?> homeBaseSourceAssets = {};
Future<Map<String, Object?>> homeBaseLoadFonts({
  bool loadForTest = false,
}) async {
  for (final entry in {
    'logo': homeBaseLogo,
    'outline': homeBaseOutline,
  }.entries) {
    try {
      final text = await rootBundle.loadString(entry.value),
          lower = text.toLowerCase();
      final valid = entry.key == 'logo'
          ? text.contains('71.41') && text.contains('24.0003')
          : lower.contains('#d1d1d1') &&
                lower.contains('stroke-width="1.5"') &&
                text.contains('width="28"');
      homeBaseSourceAssets[entry.key] = {
        'available': true,
        'valid': valid,
        'path': entry.value,
        'characters': text.length,
      };
    } catch (_) {
      homeBaseSourceAssets[entry.key] = {
        'available': false,
        'valid': false,
        'path': entry.value,
      };
    }
  }
  return {
    ...await common.logoutInspectFonts(loadForTest: loadForTest),
    'homeSources': homeBaseSourceAssets,
  };
}

List<ContentItem> homeBaseContents() =>
    archive.archiveAllContents().take(4).toList();

class HomeBaseServer {
  HomeBaseServer(this.kind) {
    if (kind == 'empty') {
      records.clear();
    } else {
      records.removeRange(4, records.length);
    }
  }
  final String kind;
  final records = archive.archiveAllRecords(),
      requests = <Map<String, Object?>>[],
      unexpected = <String>[];
  int bookmarkCalls = 0, feedCalls = 0, viewCalls = 0, writeCalls = 0;
  Completer<bool>? bookmarkGate;
  bool failNextBookmark = false;
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  late final client = MockClient((r) async {
    final path = r.url.path, q = r.url.queryParameters;
    requests.add({'method': r.method, 'path': path, 'query': q});
    if (path == '/api/v1/auth/refresh' || path == '/api/v1/auth/guest') {
      return json({
        'access_token': 'fixture-access',
        'refresh_token': 'fixture-refresh',
        'expires_in': 3600,
        'refresh_expires_in': 86400,
      }, 201);
    }
    if (path == '/api/v1/users/me') {
      return json({
        'id': 1,
        'email': null,
        'display_name': '홈 화면 검증',
        'is_guest': true,
        'created_at': '2026-10-18T00:00:00Z',
        'linked_providers': <String>[],
      });
    }
    if (path == '/api/v1/users/me/stats') {
      return json({'saved_count': 999, 'reopened_count': 231});
    }
    if (path == '/api/v1/categories') {
      return json(archive.archiveAllCategoryMaps);
    }
    if (path == '/api/v1/feed') {
      feedCalls++;
      final rows = records
          .where(
            (v) =>
                (q['is_favorite'] == null ||
                    v['is_favorite'] == (q['is_favorite'] == 'true')) &&
                (q['category_id'] == null ||
                    (v['categories'] as List).any(
                      (c) => (c as Map)['id'].toString() == q['category_id'],
                    )) &&
                '${v['title']} ${v['summary']}'.toLowerCase().contains(
                  (q['q'] ?? '').toLowerCase(),
                ),
          )
          .toList();
      return json({'items': rows, 'next_cursor': null});
    }
    if (path == '/api/v1/metrics/events') return json({}, 201);
    if (path.endsWith('/view')) {
      viewCalls++;
      return json({}, 201);
    }
    if (path == '/api/v1/auth/share-credential') {
      return json({
        'share_token': 'fixture-share',
        'expires_at': '2030-10-18T00:00:00Z',
        'user_id': 1,
        'session_id': 1,
      });
    }
    if (path == '/api/v1/auth/logout') return http.Response('', 204);
    final match = RegExp(
      r'^/api/v1/contents/(\d+)(/favorite)?$',
    ).firstMatch(path);
    if (match != null) {
      final i = records.indexWhere((v) => v['id'] == int.parse(match[1]!));
      if (i < 0) return json({'detail': 'Unknown memory content'}, 404);
      if (match[2] != null && r.method == 'PUT') {
        bookmarkCalls++;
        final accepted = bookmarkGate == null
            ? true
            : await bookmarkGate!.future;
        if (!accepted || failNextBookmark) {
          failNextBookmark = false;
          return json({'detail': '홈 북마크 대역 실패'}, 503);
        }
        final body = jsonDecode(r.body) as Map;
        records[i] = {...records[i], 'is_favorite': body['is_favorite']};
      }
      return json(records[i]);
    }
    if (r.method != 'GET') writeCalls++;
    unexpected.add('${r.method} $path');
    return json({'detail': 'Unsupported home memory request'}, 501);
  });
}
