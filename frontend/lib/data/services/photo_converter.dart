import 'dart:convert';

import 'package:flutter/services.dart';

/// HEIF brands (ISO/IEC 23008-12) for still images and image sequences.
/// AVIF also lists `mif1`, so its own brand is checked first.
const _heifBrands = {
  'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'hevm', 'hevs', //
  'mif1', 'msf1',
};
const _avifBrands = {'avif', 'avis'};

/// Whether [bytes] start with an ISO BMFF `ftyp` box naming a HEIF brand.
/// File names and extensions are not trusted.
bool isHeif(Uint8List bytes) {
  if (bytes.length < 16 ||
      ascii.decode(bytes.sublist(4, 8), allowInvalid: true) != 'ftyp') {
    return false;
  }
  final size = ByteData.sublistView(bytes, 0, 4).getUint32(0);
  final end = size < bytes.length ? size : bytes.length;
  final brands = <String>{
    // Offset 12 holds the minor version, not a brand.
    for (var offset = 8; offset + 4 <= end; offset += 4)
      if (offset != 12)
        ascii.decode(bytes.sublist(offset, offset + 4), allowInvalid: true),
  };
  return !brands.any(_avifBrands.contains) && brands.any(_heifBrands.contains);
}

/// [name] with its extension replaced by `.jpg`.
String jpegName(String name) {
  final dot = name.lastIndexOf('.');
  return '${dot < 0 ? name : name.substring(0, dot)}.jpg';
}

const _channel = MethodChannel('com.huturu.app/image');

/// The photo to preview and upload. HEIC/HEIF becomes a full-resolution,
/// upright, quality 90 JPEG without location data; every other format and
/// any conversion failure keep the selected bytes and name unchanged, so the
/// server decides as before (#380).
Future<({Uint8List bytes, String name})> preparePhotoForUpload(
  Uint8List bytes,
  String name,
) async {
  final original = (bytes: bytes, name: name);
  if (!isHeif(bytes)) return original;
  try {
    final jpeg = await _channel.invokeMethod<Uint8List>('heicToJpeg', {
      'bytes': bytes,
      'quality': 90,
    });
    if (jpeg == null ||
        jpeg.length < 3 ||
        jpeg[0] != 0xFF ||
        jpeg[1] != 0xD8 ||
        jpeg[2] != 0xFF) {
      return original;
    }
    return (bytes: jpeg, name: jpegName(name));
  } on PlatformException {
    return original;
  } on MissingPluginException {
    return original;
  }
}
