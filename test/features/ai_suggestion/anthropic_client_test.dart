import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnthropicApiKeyProvider', () {
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
