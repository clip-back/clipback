import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ShareReceiverApp());
}

class ShareReceiverApp extends StatelessWidget {
  const ShareReceiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clipback Share Receiver',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
      home: const ShareReceiverPage(),
    );
  }
}

class ShareReceiverPage extends StatefulWidget {
  const ShareReceiverPage({super.key});

  @override
  State<ShareReceiverPage> createState() => _ShareReceiverPageState();
}

class _ShareReceiverPageState extends State<ShareReceiverPage> {
  static const _channel = MethodChannel('com.clipback.share_receiver/intent');

  final _backendUrlController = TextEditingController(
    text: 'http://10.0.2.2:8000',
  );

  SharePayload _payload = SharePayload.empty();
  String _resultText = '';
  String? _accessToken;
  String? _authenticatedBaseUrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
    unawaited(_loadInitialPayload());
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPayload() async {
    final payload = await _channel.invokeMapMethod<String, dynamic>(
      'getInitialSharePayload',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _payload = SharePayload.fromMap(payload);
    });
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onSharePayload') {
      return;
    }
    final arguments = call.arguments;
    if (arguments is! Map) {
      return;
    }

    setState(() {
      _payload = SharePayload.fromMap(
        arguments.map((key, value) => MapEntry(key.toString(), value)),
      );
      _resultText = '';
    });
  }

  Future<void> _sendToBackend() async {
    setState(() {
      _sending = true;
      _resultText = 'Sending...';
    });

    try {
      final response = await _postSharePayload();
      setState(() {
        _resultText = response;
      });
    } catch (error) {
      setState(() {
        _resultText = 'Failed\n\n$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<String> _postSharePayload() async {
    final baseUrl = _backendUrlController.text.trim().replaceFirst(
      RegExp(r'/$'),
      '',
    );
    final uri = Uri.parse('$baseUrl/api/v1/contents/share');
    final client = HttpClient();

    try {
      final accessToken =
          _accessToken != null && _authenticatedBaseUrl == baseUrl
          ? _accessToken!
          : await _createGuestAccessToken(client, baseUrl);
      _accessToken = accessToken;
      _authenticatedBaseUrl = baseUrl;
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      request.write(jsonEncode(_payload.toBackendJson()));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return 'HTTP ${response.statusCode}\n\n$body';
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _createGuestAccessToken(
    HttpClient client,
    String baseUrl,
  ) async {
    final request = await client.postUrl(
      Uri.parse('$baseUrl/api/v1/auth/guest'),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.created) {
      throw HttpException(
        'Guest auth failed: HTTP ${response.statusCode} $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['access_token'] is! String) {
      throw const FormatException('Guest auth response has no access_token');
    }
    return decoded['access_token'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clipback Share Receiver')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Instagram 공유 payload를 확인하고 guest token을 자동 발급한 뒤 '
            'backend /api/v1/contents/share로 전송합니다.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _backendUrlController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Backend base URL',
              helperText: 'Emulator: http://10.0.2.2:8000, Device: Mac LAN IP',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _sendToBackend,
            icon: const Icon(Icons.send),
            label: Text(_sending ? 'Sending...' : 'Send to Backend'),
          ),
          const SizedBox(height: 20),
          _Section(title: 'Payload', body: _payload.toPrettyText()),
          const SizedBox(height: 16),
          _Section(
            title: 'Request JSON',
            body: _prettyJson(_payload.toBackendJson()),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Result',
            body: _resultText.isEmpty ? 'No response yet.' : _resultText,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(body),
        ),
      ],
    );
  }
}

class SharePayload {
  const SharePayload({
    required this.action,
    required this.mimeType,
    required this.rawText,
    required this.subject,
    required this.title,
    required this.url,
    required this.sourceApp,
    required this.platform,
    required this.attachments,
  });

  final String? action;
  final String? mimeType;
  final String? rawText;
  final String? subject;
  final String? title;
  final String? url;
  final String? sourceApp;
  final String platform;
  final List<ShareAttachment> attachments;

  factory SharePayload.empty() {
    return const SharePayload(
      action: null,
      mimeType: null,
      rawText: null,
      subject: null,
      title: null,
      url: null,
      sourceApp: null,
      platform: 'android',
      attachments: [],
    );
  }

  factory SharePayload.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return SharePayload.empty();
    }

    final attachmentsValue = map['attachments'];
    final attachments = attachmentsValue is List
        ? attachmentsValue
              .whereType<Map>()
              .map(
                (item) => ShareAttachment.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList()
        : <ShareAttachment>[];

    return SharePayload(
      action: _stringOrNull(map['action']),
      mimeType: _stringOrNull(map['mime_type']),
      rawText: _stringOrNull(map['raw_text']),
      subject: _stringOrNull(map['subject']),
      title: _stringOrNull(map['title']),
      url: _stringOrNull(map['url']),
      sourceApp: _stringOrNull(map['source_app']),
      platform: _stringOrNull(map['platform']) ?? 'android',
      attachments: attachments,
    );
  }

  Map<String, Object?> toBackendJson() {
    return {
      'url': url,
      'raw_text': rawText,
      'mime_type': mimeType,
      'source_app': sourceApp,
      'platform': platform,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
      'category_ids': <int>[],
      'is_favorite': false,
    };
  }

  String toPrettyText() {
    final buffer = StringBuffer()
      ..writeln('action: ${action ?? ''}')
      ..writeln('mime_type: ${mimeType ?? ''}')
      ..writeln('source_app: ${sourceApp ?? ''}')
      ..writeln('platform: $platform')
      ..writeln('title: ${title ?? ''}')
      ..writeln('subject: ${subject ?? ''}')
      ..writeln('url: ${url ?? ''}')
      ..writeln()
      ..writeln('raw_text:')
      ..writeln(rawText ?? '')
      ..writeln()
      ..writeln('attachments: ${attachments.length}');

    for (final (index, attachment) in attachments.indexed) {
      buffer.writeln('${index + 1}. ${attachment.toPrettyText()}');
    }

    return buffer.toString();
  }
}

class ShareAttachment {
  const ShareAttachment({
    required this.filename,
    required this.mimeType,
    required this.uri,
    required this.sizeBytes,
  });

  final String? filename;
  final String? mimeType;
  final String? uri;
  final int? sizeBytes;

  factory ShareAttachment.fromMap(Map<String, dynamic> map) {
    return ShareAttachment(
      filename: _stringOrNull(map['filename']),
      mimeType: _stringOrNull(map['mime_type']),
      uri: _stringOrNull(map['uri']),
      sizeBytes: _intOrNull(map['size_bytes']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'filename': filename,
      'mime_type': mimeType,
      'uri': uri,
      'size_bytes': sizeBytes,
    };
  }

  String toPrettyText() {
    return 'uri=${uri ?? ''}, mime_type=${mimeType ?? ''}, '
        'filename=${filename ?? ''}, size_bytes=${sizeBytes ?? ''}';
  }
}

String _prettyJson(Map<String, Object?> value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

String? _stringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int? _intOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
