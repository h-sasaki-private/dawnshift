import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dawnshift/core/models/routine_suggestion.dart';
import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

class MockHttpClient implements HttpClientInterface {
  MockHttpClient._(this._handler);

  final Future<StreamedHttpResponse> Function() _handler;

  factory MockHttpClient.streamingSuccess() {
    return MockHttpClient._(() async {
      final firstDelta = jsonEncode({
        'type': 'content_block_delta',
        'delta': {
          'type': 'text_delta',
          'text':
              '{"target_bedtime":"23:00","routines":[{"title":"起床後に日光を浴びる","duration_minutes":10},',
        },
      });
      final secondDelta = jsonEncode({
        'type': 'content_block_delta',
        'delta': {
          'type': 'text_delta',
          'text': '{"title":"白湯を飲む","duration_minutes":5}]}',
        },
      });

      final chunks = <String>[
        'event: message_start\n',
        'data: {"type":"message_start"}\n\n',
        'event: content_block_delta\n',
        'data: $firstDelta\n\n',
        'event: content_block_delta\n',
        'data: $secondDelta\n\n',
        'event: message_stop\n',
        'data: {"type":"message_stop"}\n\n',
      ];

      final controller = StreamController<String>();
      unawaited(() async {
        for (final chunk in chunks) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          controller.add(chunk);
        }
        await controller.close();
      }());

      return StreamedHttpResponse(statusCode: 200, body: controller.stream);
    });
  }

  factory MockHttpClient.unauthorized() {
    return MockHttpClient._(
      () async => StreamedHttpResponse(
        statusCode: 401,
        body: Stream<String>.value('{"error":"unauthorized"}'),
      ),
    );
  }

  factory MockHttpClient.networkError() {
    return MockHttpClient._(
      () async => throw const SocketException('Network error'),
    );
  }

  factory MockHttpClient.emptyStream() {
    return MockHttpClient._(
      () async => StreamedHttpResponse(
        statusCode: 200,
        body: Stream<String>.fromIterable(const [
          'event: message_start\n',
          'data: {"type":"message_start"}\n\n',
          'event: message_stop\n',
          'data: {"type":"message_stop"}\n\n',
        ]),
      ),
    );
  }

  @override
  Future<StreamedHttpResponse> postStream(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    return _handler();
  }
}

void main() {
  group('AnthropicApiKeyProvider', () {
    test('flutter_dotenv から API キーを取得できる', () {
      final dotEnv = DotEnv()..testLoad(fileInput: 'ANTHROPIC_API_KEY=test-key');

      final apiKey = AnthropicApiKeyProvider.fromDotEnv(dotEnv);

      expect(apiKey, 'test-key');
    });

    test('環境変数 ANTHROPIC_API_KEY から API キーを取得できる', () {
      final apiKey = AnthropicApiKeyProvider.fromEnvironment(
        const {'ANTHROPIC_API_KEY': 'test-api-key'},
      );

      expect(apiKey, 'test-api-key');
    });

    test('環境変数に API キーがない場合は ArgumentError を投げる', () {
      expect(
        () => AnthropicApiKeyProvider.fromEnvironment(const {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('dotenv に API キーがない場合は ArgumentError を投げる', () {
      final dotEnv = DotEnv()..testLoad(fileInput: 'OTHER=value');

      expect(
        () => AnthropicApiKeyProvider.fromDotEnv(dotEnv),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('AnthropicClient', () {
    test('厚労省ガイドラインがシステムプロンプトに含まれている', () {
      final client = AnthropicClient(apiKey: 'test-api-key');

      expect(client.systemPrompt, contains('健康づくりのための睡眠ガイド2023'));
      expect(client.systemPrompt, contains('6〜9時間'));
      expect(client.systemPrompt, contains('朝の光'));
    });

    test('ユーザーの睡眠情報を含むリクエスト本文を構築できる', () {
      final client = AnthropicClient(apiKey: 'test-api-key');

      final requestBody = client.buildRequestBody(
        bedtime: '23:15',
        wakeTime: '06:45',
        sleepDuration: 7.5,
      );

      expect(requestBody, contains('"stream":true'));
      expect(requestBody, contains('23:15'));
      expect(requestBody, contains('06:45'));
      expect(requestBody, contains('7.5'));
    });

    test('ストリーミング応答からルーティン提案と初回受信時間を返す', () async {
      final client = AnthropicClient(
        apiKey: 'test-api-key',
        httpClient: MockHttpClient.streamingSuccess(),
      );

      final result = await client.fetchRoutineSuggestion(
        bedtime: '23:00',
        wakeTime: '07:00',
        sleepDuration: 8.0,
      );

      expect(result.suggestion.targetBedtime, '23:00');
      expect(result.suggestion.routines, hasLength(2));
      expect(result.suggestion.routines.first.title, '起床後に日光を浴びる');
      expect(result.timeToFirstChunk, lessThan(const Duration(seconds: 3)));
    });

    test('401 の場合は AnthropicAuthException を投げる', () async {
      final client = AnthropicClient(
        apiKey: 'invalid-key',
        httpClient: MockHttpClient.unauthorized(),
      );

      expect(
        () => client.fetchRoutineSuggestion(
          bedtime: '23:00',
          wakeTime: '07:00',
          sleepDuration: 8.0,
        ),
        throwsA(isA<AnthropicAuthException>()),
      );
    });

    test('ネットワークエラーの場合は AnthropicNetworkException を投げる', () async {
      final client = AnthropicClient(
        apiKey: 'test-api-key',
        httpClient: MockHttpClient.networkError(),
      );

      expect(
        () => client.fetchRoutineSuggestion(
          bedtime: '23:00',
          wakeTime: '07:00',
          sleepDuration: 8.0,
        ),
        throwsA(isA<AnthropicNetworkException>()),
      );
    });

    test('本文にテキスト差分がない場合は AnthropicParseException を投げる', () async {
      final client = AnthropicClient(
        apiKey: 'test-api-key',
        httpClient: MockHttpClient.emptyStream(),
      );

      expect(
        () => client.fetchRoutineSuggestion(
          bedtime: '23:00',
          wakeTime: '07:00',
          sleepDuration: 8.0,
        ),
        throwsA(isA<AnthropicParseException>()),
      );
    });
  });

  group('RoutineSuggestion', () {
    test('JSON からパースできる', () {
      final suggestion = RoutineSuggestion.fromJson(const {
        'target_bedtime': '22:45',
        'routines': [
          {'title': '白湯を飲む', 'duration_minutes': 5},
          {'title': '軽いストレッチ', 'duration_minutes': 10},
        ],
      });

      expect(suggestion.targetBedtime, '22:45');
      expect(suggestion.routines, hasLength(2));
      expect(suggestion.routines.first.durationMinutes, 5);
    });
  });
}
