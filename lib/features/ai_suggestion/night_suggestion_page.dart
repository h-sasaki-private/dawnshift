import 'package:dawnshift/core/models/routine_suggestion.dart';
import 'package:dawnshift/core/models/subscription_status.dart';
import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:dawnshift/features/ai_suggestion/night_suggestion_service.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:dawnshift/features/subscription/subscription_service.dart';
import 'package:flutter/material.dart';

class NightSuggestionPage extends StatefulWidget {
  const NightSuggestionPage({
    super.key,
    required this.sleepRepository,
    required this.routineRepository,
    required this.anthropicClient,
    required this.subscriptionService,
    this.now = _now,
  });

  final SleepRecordRepository sleepRepository;
  final RoutineRepository routineRepository;
  final AnthropicClient anthropicClient;
  final SubscriptionService subscriptionService;
  final DateTime Function() now;

  static DateTime _now() => DateTime.now();

  @override
  State<NightSuggestionPage> createState() => _NightSuggestionPageState();
}

class _NightSuggestionPageState extends State<NightSuggestionPage> {
  late final NightSuggestionService _service;
  SubscriptionStatus? _subscriptionStatus;
  RoutineSuggestionResult? _result;
  String? _message;
  bool _isLoading = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _service = NightSuggestionService(
      sleepRepository: widget.sleepRepository,
      routineRepository: widget.routineRepository,
      anthropicClient: widget.anthropicClient,
    );
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final status = await widget.subscriptionService.getCurrentStatus();
    if (!mounted) {
      return;
    }

    setState(() {
      _subscriptionStatus = status;
    });
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

  Future<void> _purchasePremium() async {
    setState(() {
      _isPurchasing = true;
      _message = null;
    });

    try {
      final status = await widget.subscriptionService.purchasePremium();
      if (!mounted) {
        return;
      }
      setState(() {
        _subscriptionStatus = status;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = '購入の開始に失敗しました。時間をおいて再度お試しください。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    final status = await widget.subscriptionService.restorePurchases();
    if (!mounted) {
      return;
    }

    setState(() {
      _subscriptionStatus = status;
      _message = status.isPremium ? '購入状態を復元しました。' : '復元できる購入は見つかりませんでした。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionStatus = _subscriptionStatus;
    final suggestion = _result?.suggestion;
    final timeToFirstChunk = _result?.timeToFirstChunk;

    return Scaffold(
      appBar: AppBar(title: const Text('今夜のAI提案')),
      body: subscriptionStatus == null
          ? const Center(child: CircularProgressIndicator())
          : subscriptionStatus.isPremium
          ? ListView(
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
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PaywallCard(),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('purchase-premium'),
            onPressed: _isPurchasing ? null : _purchasePremium,
            child: Text(_isPurchasing ? '購入処理中...' : 'プレミアムを開始'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('restore-premium'),
            onPressed: _restorePurchases,
            child: const Text('購入を復元'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
        ],
      ),
    );
  }
}

class _PaywallCard extends StatelessWidget {
  const _PaywallCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('AIアドバイスはプレミアム限定です'),
            SizedBox(height: 12),
            Text('無料プラン'),
            Text('睡眠記録・基本ルーティン設定'),
            SizedBox(height: 12),
            Text('プレミアムプラン'),
            Text('AIアドバイス・週次レポート・ルーティン上限解放'),
          ],
        ),
      ),
    );
  }
}
