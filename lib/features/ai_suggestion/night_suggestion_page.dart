import 'package:dawnshift/core/models/routine_suggestion.dart';
import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:dawnshift/features/ai_suggestion/night_suggestion_service.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:flutter/material.dart';

class NightSuggestionPage extends StatefulWidget {
  const NightSuggestionPage({
    super.key,
    required this.sleepRepository,
    required this.routineRepository,
    required this.anthropicClient,
    this.now = _now,
  });

  final SleepRecordRepository sleepRepository;
  final RoutineRepository routineRepository;
  final AnthropicClient anthropicClient;
  final DateTime Function() now;

  static DateTime _now() => DateTime.now();

  @override
  State<NightSuggestionPage> createState() => _NightSuggestionPageState();
}

class _NightSuggestionPageState extends State<NightSuggestionPage> {
  late final NightSuggestionService _service;
  RoutineSuggestionResult? _result;
  String? _message;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _service = NightSuggestionService(
      sleepRepository: widget.sleepRepository,
      routineRepository: widget.routineRepository,
      anthropicClient: widget.anthropicClient,
    );
  }

  Future<void> _generateSuggestion() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await _service.generateSuggestion(from: widget.now());
      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } on NoSleepRecordsException {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '睡眠記録を1件以上登録すると提案を作成できます';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _applySuggestion() async {
    final result = _result;
    if (result == null) {
      return;
    }

    await _service.applySuggestion(result.suggestion);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('明日の朝ルーティンに反映しました')));
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _result?.suggestion;
    final timeToFirstChunk = _result?.timeToFirstChunk;

    return Scaffold(
      appBar: AppBar(title: const Text('今夜のAI提案')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            key: const Key('generate-night-suggestion'),
            onPressed: _isLoading ? null : _generateSuggestion,
            child: Text(_isLoading ? '提案を作成中...' : '提案を作成'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
          if (suggestion != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('推奨就寝時刻 ${suggestion.targetBedtime}'),
                    if (timeToFirstChunk != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '初回応答 ${timeToFirstChunk.inMilliseconds / 1000}秒',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final item in suggestion.routines)
              Card(
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text('${item.durationMinutes}分'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('apply-night-suggestion'),
              onPressed: _applySuggestion,
              child: const Text('明日の朝ルーティンに適用'),
            ),
          ],
        ],
      ),
    );
  }
}
