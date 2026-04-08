import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dawnshift/core/models/routine_suggestion.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AnthropicAuthException implements Exception {
  const AnthropicAuthException(this.message);

  final String message;

  @override
  String toString() => 'AnthropicAuthException: $message';
}

class AnthropicNetworkException implements Exception {
  const AnthropicNetworkException(this.message);

  final String message;

  @override
  String toString() => 'AnthropicNetworkException: $message';
}

class AnthropicParseException implements Exception {
  const AnthropicParseException(this.message);

  final String message;

  @override
  String toString() => 'AnthropicParseException: $message';
}

class AnthropicApiKeyProvider {
  static String fromDotEnv([DotEnv? dotEnv]) {
    final source = dotEnv ?? dotenv;

    if (!source.isInitialized) {
      throw ArgumentError(
        'dotenv が初期化されていません。ANTHROPIC_API_KEY を読み込めません。',
      );
    }

    final apiKey = source.env['ANTHROPIC_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError(
        '環境変数 ANTHROPIC_API_KEY が設定されていません。',
      );
    }

    return apiKey;
  }

  static String fromEnvironment([Map<String, String>? environment]) {
    final source = environment ?? Platform.environment;
    final apiKey = source['ANTHROPIC_API_KEY']?.trim();

    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError(
        '環境変数 ANTHROPIC_API_KEY が設定されていません。',
      );
    }

    return apiKey;
  }
}

abstract class HttpClientInterface {
  Future<StreamedHttpResponse> postStream(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });
}

class StreamedHttpResponse {
  const StreamedHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Stream<String> body;
}

class AnthropicClient {
  AnthropicClient({
    required this.apiKey,
    HttpClientInterface? httpClient,
    Stopwatch Function()? stopwatchFactory,
  })  : _httpClient = httpClient ?? _DefaultHttpClient(),
        _stopwatchFactory = stopwatchFactory ?? Stopwatch.new {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError(
        'APIキーが空です。環境変数 ANTHROPIC_API_KEY を設定してください。',
      );
    }
  }

  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-3-5-haiku-latest';

  final String apiKey;
  final HttpClientInterface _httpClient;
  final Stopwatch Function() _stopwatchFactory;

  String get systemPrompt => '''
あなたは睡眠改善の専門アドバイザーです。
厚生労働省「健康づくりのための睡眠ガイド2023」の要点を守り、
実行しやすい翌朝のルーティンを JSON で提案してください。

要点:
- 成人の睡眠時間はおおむね 6〜9時間を目安にする
- 就寝時刻と起床時刻のばらつきを減らす
- 就寝前のカフェイン、飲酒、スマートフォン利用を避ける
- 朝の光を浴びて体内時計を整える

出力形式:
{
  "target_bedtime": "HH:MM",
  "routines": [
    {"title": "ルーティン名", "duration_minutes": 10}
  ]
}
''';

  String buildUserPrompt({
    required String bedtime,
    required String wakeTime,
    required double sleepDuration,
  }) {
    return '''
昨夜の就寝時刻: $bedtime
今朝の起床時刻: $wakeTime
睡眠時間: ${sleepDuration.toStringAsFixed(1)}時間

このユーザーが無理なく続けられる翌朝のルーティンを2件提案し、
推奨就寝時刻も返してください。
''';
  }

  String buildRequestBody({
    required String bedtime,
    required String wakeTime,
    required double sleepDuration,
  }) {
    return jsonEncode({
      'model': _model,
      'max_tokens': 512,
      'stream': true,
      'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': buildUserPrompt(
            bedtime: bedtime,
            wakeTime: wakeTime,
            sleepDuration: sleepDuration,
          ),
        },
      ],
    });
  }

  Future<RoutineSuggestionResult> fetchRoutineSuggestion({
    required String bedtime,
    required String wakeTime,
    required double sleepDuration,
  }) async {
    final stopwatch = _stopwatchFactory()..start();
    Duration? firstChunkLatency;
    final textBuffer = StringBuffer();

    try {
      final response = await _httpClient.postStream(
        Uri.parse(_apiUrl),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
          'accept': 'text/event-stream',
        },
        body: buildRequestBody(
          bedtime: bedtime,
          wakeTime: wakeTime,
          sleepDuration: sleepDuration,
        ),
      );

      if (response.statusCode == 401) {
        throw const AnthropicAuthException('APIキーが無効です。');
      }
      if (response.statusCode != 200) {
        throw AnthropicNetworkException(
          'APIエラー: ステータスコード ${response.statusCode}',
        );
      }

      await for (final chunk in response.body) {
        firstChunkLatency ??= stopwatch.elapsed;
        _appendTextDelta(chunk, textBuffer);
      }

      if (firstChunkLatency == null) {
        throw const AnthropicParseException('ストリーミング応答が空です。');
      }
      if (textBuffer.isEmpty) {
        throw const AnthropicParseException('応答から提案テキストを取得できませんでした。');
      }

      final suggestionJson =
          jsonDecode(textBuffer.toString()) as Map<String, dynamic>;

      return RoutineSuggestionResult(
        suggestion: RoutineSuggestion.fromJson(suggestionJson),
        timeToFirstChunk: firstChunkLatency,
      );
    } on SocketException catch (error) {
      throw AnthropicNetworkException('ネットワークエラー: ${error.message}');
    } on FormatException catch (error) {
      throw AnthropicParseException('JSONパースに失敗しました: ${error.message}');
    }
  }

  void _appendTextDelta(String chunk, StringBuffer buffer) {
    for (final line in const LineSplitter().convert(chunk)) {
      if (!line.startsWith('data: ')) {
        continue;
      }

      final payload = line.substring(6);
      if (payload == '[DONE]') {
        continue;
      }

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      if (decoded['type'] != 'content_block_delta') {
        continue;
      }

      final delta = decoded['delta'] as Map<String, dynamic>;
      if (delta['type'] == 'text_delta') {
        buffer.write(delta['text'] as String);
      }
    }
  }
}

class _DefaultHttpClient implements HttpClientInterface {
  @override
  Future<StreamedHttpResponse> postStream(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = HttpClient();
    final request = await client.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);

    final response = await request.close();
    final stream = response.transform(utf8.decoder);

    return StreamedHttpResponse(
      statusCode: response.statusCode,
      body: stream,
    );
  }
}
