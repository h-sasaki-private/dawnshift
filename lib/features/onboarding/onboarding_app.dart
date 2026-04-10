import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:dawnshift/features/ai_suggestion/night_suggestion_page.dart';
import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:dawnshift/core/models/user_profile.dart';
import 'package:dawnshift/features/onboarding/onboarding_page.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/review/review_page.dart';
import 'package:dawnshift/features/routine/morning_routine_page.dart';
import 'package:dawnshift/features/routine/routine_repository.dart';
import 'package:dawnshift/features/routine/routine_settings_page.dart';
import 'package:dawnshift/features/settings/settings_page.dart';
import 'package:dawnshift/features/sleep/sleep_record_page.dart'
    show SleepRecordPage;
import 'package:dawnshift/features/sleep/sleep_record_repository.dart';
import 'package:dawnshift/features/subscription/subscription_service.dart';
import 'package:flutter/material.dart';

class OnboardingApp extends StatefulWidget {
  const OnboardingApp({
    super.key,
    required this.repository,
    required this.authService,
    required this.sleepRepository,
    required this.routineRepository,
    required this.anthropicClient,
    required this.subscriptionService,
    this.currentBedtimePicker,
    this.currentWakeTimePicker,
    this.idealBedtimePicker,
    this.idealWakeTimePicker,
  });

  final OnboardingRepository repository;
  final AuthService authService;
  final SleepRecordRepository sleepRepository;
  final RoutineRepository routineRepository;
  final AnthropicClient anthropicClient;
  final SubscriptionService subscriptionService;
  final TimePickerCallback? currentBedtimePicker;
  final TimePickerCallback? currentWakeTimePicker;
  final TimePickerCallback? idealBedtimePicker;
  final TimePickerCallback? idealWakeTimePicker;

  @override
  State<OnboardingApp> createState() => _OnboardingAppState();
}

class _OnboardingAppState extends State<OnboardingApp> {
  UserProfile? _profile;
  var _loading = true;
  var _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final completed = await widget.repository.isCompleted();
    final profile = await widget.repository.loadProfile();

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
      _showOnboarding = !completed;
      _loading = false;
    });
  }

  void _openOnboarding() {
    setState(() {
      _showOnboarding = true;
    });
  }

  void _handleCompleted(UserProfile profile) {
    setState(() {
      _profile = profile;
      _showOnboarding = false;
    });
  }

  void _handleSkipped() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_showOnboarding) {
      return OnboardingPage(
        repository: widget.repository,
        initialProfile: _profile,
        currentBedtimePicker: widget.currentBedtimePicker,
        currentWakeTimePicker: widget.currentWakeTimePicker,
        idealBedtimePicker: widget.idealBedtimePicker,
        idealWakeTimePicker: widget.idealWakeTimePicker,
        onCompleted: _handleCompleted,
        onSkipped: _handleSkipped,
      );
    }

    return _HomePage(
      profile: _profile,
      onEdit: _openOnboarding,
      authService: widget.authService,
      sleepRepository: widget.sleepRepository,
      routineRepository: widget.routineRepository,
      anthropicClient: widget.anthropicClient,
      subscriptionService: widget.subscriptionService,
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.profile,
    required this.onEdit,
    required this.authService,
    required this.sleepRepository,
    required this.routineRepository,
    required this.anthropicClient,
    required this.subscriptionService,
  });

  final UserProfile? profile;
  final VoidCallback onEdit;
  final AuthService authService;
  final SleepRecordRepository sleepRepository;
  final RoutineRepository routineRepository;
  final AnthropicClient anthropicClient;
  final SubscriptionService subscriptionService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile == null
                    ? 'まだプロフィールは登録されていません。'
                    : profile!.toPromptContext(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('edit-onboarding'),
                onPressed: onEdit,
                child: const Text('プロフィールを編集'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('open-sleep-record'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SleepRecordPage(repository: sleepRepository),
                    ),
                  );
                },
                child: const Text('睡眠記録'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('open-morning-routine'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          MorningRoutinePage(repository: routineRepository),
                    ),
                  );
                },
                child: const Text('朝ルーティン実行'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('open-routine-settings'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RoutineSettingsPage(repository: routineRepository),
                    ),
                  );
                },
                child: const Text('ルーティン設定'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('open-night-suggestion'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NightSuggestionPage(
                        sleepRepository: sleepRepository,
                        routineRepository: routineRepository,
                        anthropicClient: anthropicClient,
                        subscriptionService: subscriptionService,
                      ),
                    ),
                  );
                },
                child: const Text('AI夜の提案'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('open-review'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReviewPage(
                        sleepRepository: sleepRepository,
                        routineRepository: routineRepository,
                      ),
                    ),
                  );
                },
                child: const Text('振り返り'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('open-settings'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsPage(authService: authService),
                    ),
                  );
                },
                child: const Text('設定'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
