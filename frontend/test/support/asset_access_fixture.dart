import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

http.Response originalAccessFixture(
  int assetId,
  List<int> bytes, {
  String mimeType = 'image/png',
}) => http.Response(
  jsonEncode({
    'asset_id': assetId,
    'mode': 'proxy',
    'url': '/api/v1/uploads/assets/$assetId',
    'expires_at': null,
    'mime_type': mimeType,
    'size_bytes': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  }),
  200,
  headers: {'content-type': 'application/json'},
);
