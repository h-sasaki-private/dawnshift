import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:dawnshift/core/models/user_profile.dart';
import 'package:dawnshift/features/onboarding/onboarding_page.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:dawnshift/features/settings/settings_page.dart';
import 'package:flutter/material.dart';

class OnboardingApp extends StatefulWidget {
  const OnboardingApp({
    super.key,
    required this.repository,
    required this.authService,
    this.currentBedtimePicker,
    this.currentWakeTimePicker,
    this.idealBedtimePicker,
    this.idealWakeTimePicker,
  });

  final OnboardingRepository repository;
  final AuthService authService;
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
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.profile,
    required this.onEdit,
    required this.authService,
  });

  final UserProfile? profile;
  final VoidCallback onEdit;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
      ),
    );
  }
}
