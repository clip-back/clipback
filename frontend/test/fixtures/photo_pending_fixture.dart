// D08 uses the existing D09 submitted-photo summary policy, not a new D07 crop.
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'link_pending_fixture.dart' as base;
import 'splash_alignment_fixture.dart' as b;
export 'link_pending_fixture.dart' show pendingSession;

const photoName = 'selected-photo.png';

class PendingPhoto {
  const PendingPhoto(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class PendingPhotoPicker extends FilePicker {
  PendingPhotoPicker(this.photos);
  final List<PendingPhoto> photos;
  int calls = 0, index = 0;
  bool cancelNext = false;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    calls++;
    if (cancelNext) {
      cancelNext = false;
      return null;
    }
    final selected =
        photos[index < photos.length ? index++ : photos.length - 1];
    return FilePickerResult([
      PlatformFile(
        name: selected.name,
        size: selected.bytes.length,
        bytes: selected.bytes,
      ),
    ]);
  }
}

class PhotoPendingServer extends base.LinkPendingServer {
  PhotoPendingServer(this.expectedBytes);
  final Uint8List expectedBytes;
  final uploads = <Map<String, Object?>>[];
  @override
  Map<String, Object?> content(String filename) => {
    'id': 201,
    'content_type': 'screenshot',
    'source': 'screenshot',
    'title': '저장 결과 확인',
    'summary': '제출한 사진의 결과입니다.',
    'original_url': null,
    'categories': <Object>[],
    'tags': <Object>[],
    'assets': <Object>[],
    'is_favorite': false,
    'saved_at': '2026-10-19T00:00:00Z',
    'last_viewed_at': null,
    'summary_status': 'not_requested',
  };
  bool _contains(List<int> body, List<int> needle) {
    if (needle.isEmpty) return false;
    for (var i = 0; i <= body.length - needle.length; i++) {
      if (body[i] != needle.first) continue;
      var j = 1;
      while (j < needle.length && body[i + j] == needle[j]) {
        j++;
      }
      if (j == needle.length) return true;
    }
    return false;
  }

  late final photoClient = MockClient((r) async {
    if (r.method == 'POST' && r.url.path == '/api/v1/uploads/screenshots') {
      final filename = RegExp(
        'filename="([^"]*)"',
      ).firstMatch(utf8.decode(r.bodyBytes, allowMalformed: true))?.group(1);
      submissions.add(filename ?? 'missing-filename');
      uploads.add({
        'filename': filename,
        'byteLength': expectedBytes.length,
        'originalBytesContained': _contains(r.bodyBytes, expectedBytes),
        'multipart':
            r.headers['content-type']?.startsWith('multipart/form-data') ==
            true,
      });
      gate = Completer<http.Response>();
      return gate!.future;
    }
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return http.Response.fromStream(await controlledClient.send(copy));
  });
  @override
  void close() {
    photoClient.close();
    super.close();
  }
}

Map<String, Object?> photoPendingMeasure(
  Element root, {
  required Uint8List expectedBytes,
}) {
  final m = base.linkPendingMeasure(root, prefix: 'photo-pending', photo: true);
  if (m['active'] != true) return m;
  final summary = b.splashKey(root, 'photo-pending-summary')!,
      container = summary.widget as Container;
  final image = b.splashKey(root, 'photo-pending-image')!,
      w = image.widget as Image;
  final provider = w.image;
  final bytes = provider is MemoryImage
      ? provider.bytes
      : provider is ResizeImage && (provider.imageProvider is MemoryImage)
      ? (provider.imageProvider as MemoryImage).bytes
      : null;
  Map<String, Object?> decoration(Decoration? d) => {
    'color': d is BoxDecoration ? d.color?.toARGB32() : null,
    'radius': d is BoxDecoration
        ? (d.borderRadius as BorderRadius?)?.topLeft.x
        : null,
    'borderWidth': d is BoxDecoration ? (d.border as Border?)?.top.width : null,
    'borderColor': d is BoxDecoration
        ? (d.border as Border?)?.top.color.toARGB32()
        : null,
  };
  final padding = container.padding!.resolve(TextDirection.ltr);
  Element? inner;
  image.visitAncestorElements((e) {
    if (e.widget is Container &&
        (e.widget as Container).foregroundDecoration != null) {
      inner = e;
      return false;
    }
    return true;
  });
  final heading = b.splashKey(root, 'photo-pending-input-heading')!,
      p =
          b.splashFind<RichText>(heading)!.findRenderObject()!
              as RenderParagraph,
      s = (p.text as TextSpan).style!;
  return {
    ...m,
    'summary': {
      'bounds': b.splashRect(b.splashBox(summary)),
      'padding': [padding.left, padding.top, padding.right, padding.bottom],
      'background': decoration(container.decoration),
      'foreground': decoration(container.foregroundDecoration),
    },
    'summaryImage': {
      'bounds': b.splashRect(b.splashBox(image)),
      'fit': w.fit?.name,
      'centered': w.alignment == Alignment.center,
      'label': w.semanticLabel,
      'sameBytes': bytes != null && listEquals(bytes, expectedBytes),
      'byteLength': bytes?.length,
      'clipped': image.findAncestorWidgetOfExactType<ClipRect>() != null,
      'innerBorder': inner == null
          ? null
          : decoration((inner!.widget as Container).foregroundDecoration),
    },
    'inputHeading': {
      'text': p.text.toPlainText(),
      'font': s.fontFamily,
      'size': s.fontSize,
      'weight': s.fontWeight?.value,
      'spacing': s.letterSpacing,
      'height': s.height,
      'color': s.color?.toARGB32(),
      'scaledSize': p.textScaler.scale(s.fontSize!),
    },
  };
}

Map<String, Object?> photoPendingJudgment(Map<String, Object?> m) {
  final common = base.linkPendingJudgment(m);
  if (m['active'] != true) return common;
  final style = List<String>.from(common['styleFailures'] as List),
      layout = List<String>.from(common['layoutFailures'] as List);
  final summary = m['summary'] as Map,
      box = summary['bounds'] as Map,
      image = m['summaryImage'] as Map,
      ib = image['bounds'] as Map,
      heading = m['inputHeading'] as Map;
  double n(Map r, String k) => (r[k] as num).toDouble();
  void near(String k, double a, double b) {
    if ((a - b).abs() > .2) layout.add('$k $a != $b');
  }

  near('summary height', n(box, 'height'), 89);
  near('image height', n(ib, 'height'), 57);
  near('image width', n(ib, 'width'), n(box, 'width') - 32);
  near('image inset x', n(ib, 'left') - n(box, 'left'), 16);
  near('image inset y', n(ib, 'top') - n(box, 'top'), 16);
  if (!listEquals(summary['padding'] as List, [16.0, 16.0, 16.0, 16.0])) {
    style.add('summary padding');
  }
  final bg = summary['background'] as Map,
      fg = summary['foreground'] as Map,
      inner = image['innerBorder'] as Map?;
  if (bg['color'] != 0xffffffff ||
      bg['radius'] != 8.0 ||
      fg['borderWidth'] != 1.0 ||
      fg['borderColor'] != 0xffd1d1d1 ||
      inner?['borderWidth'] != 1.0 ||
      inner?['borderColor'] != 0xffd1d1d1) {
    style.add('summary colors/borders');
  }
  if (image['fit'] != 'cover' ||
      image['centered'] != true ||
      image['sameBytes'] != true ||
      image['label'] != photoName ||
      image['clipped'] != true) {
    style.add('existing submitted photo policy/data');
  }
  if (heading['text'] != '저장할 사진' ||
      heading['font'] != 'Pretendard' ||
      heading['size'] != 16.0 ||
      heading['weight'] != 600 ||
      heading['spacing'] != -.4 ||
      heading['height'] != null ||
      heading['color'] != 0xff000000 ||
      heading['scaledSize'] != 16.0) {
    style.add('input heading');
  }
  return {
    ...common,
    'stylePassed': style.isEmpty,
    'layoutPassed': layout.isEmpty,
    'styleFailures': style,
    'layoutFailures': layout,
  };
}
