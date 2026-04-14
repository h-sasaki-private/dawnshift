// ignore_for_file: use_build_context_synchronously

import 'package:dawnshift/core/models/user_profile.dart';
import 'package:dawnshift/features/onboarding/onboarding_repository.dart';
import 'package:flutter/material.dart';

typedef TimePickerCallback = Future<TimeOfDay?> Function(
  BuildContext context,
  TimeOfDay initialTime,
);

const onboardingRoutineCandidates = <String>[
  '日光を浴びる',
  '白湯を飲む',
  '軽いストレッチ',
  '朝食をとる',
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.repository,
    required this.onCompleted,
    required this.onSkipped,
    this.initialProfile,
    this.currentBedtimePicker,
    this.currentWakeTimePicker,
    this.idealBedtimePicker,
    this.idealWakeTimePicker,
  });

  final OnboardingRepository repository;
  final UserProfile? initialProfile;
  final Future<void> Function(UserProfile) onCompleted;
  final VoidCallback onSkipped;
  final TimePickerCallback? currentBedtimePicker;
  final TimePickerCallback? currentWakeTimePicker;
  final TimePickerCallback? idealBedtimePicker;
  final TimePickerCallback? idealWakeTimePicker;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late TimeOfDay _currentBedtime;
  late TimeOfDay _currentWakeTime;
  late TimeOfDay _idealBedtime;
  late TimeOfDay _idealWakeTime;
  late final Set<String> _selectedRoutines;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _currentBedtime = _parseTime(profile?.currentBedtime) ??
        const TimeOfDay(hour: 23, minute: 30);
    _currentWakeTime =
        _parseTime(profile?.currentWakeTime) ?? const TimeOfDay(hour: 7, minute: 0);
    _idealBedtime = _parseTime(profile?.idealBedtime) ??
        const TimeOfDay(hour: 22, minute: 30);
    _idealWakeTime = _parseTime(profile?.idealWakeTime) ??
        const TimeOfDay(hour: 6, minute: 0);
    _selectedRoutines = profile == null
        ? onboardingRoutineCandidates.toSet()
        : profile.morningRoutineCandidates.toSet();
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || !value.contains(':')) {
      return null;
    }
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({
    required TimePickerCallback? picker,
    required TimeOfDay current,
    required ValueChanged<TimeOfDay> onChanged,
  }) async {
    final nextTime = picker != null
        ? await picker(context, current)
        : await showTimePicker(context: context, initialTime: current);
    if (!mounted || nextTime == null) {
      return;
    }

    setState(() {
      onChanged(nextTime);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    final profile = UserProfile(
      id: widget.initialProfile?.id,
      currentBedtime: _formatTime(_currentBedtime),
      currentWakeTime: _formatTime(_currentWakeTime),
      idealBedtime: _formatTime(_idealBedtime),
      idealWakeTime: _formatTime(_idealWakeTime),
      morningRoutineCandidates: _selectedRoutines.toList(),
      onboardingCompleted: true,
    );

    await widget.repository.saveProfile(profile);
    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
    await widget.onCompleted(profile);
  }

  Future<void> _skip() async {
    setState(() {
      _saving = true;
    });

    await widget.repository.markSkipped();
    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
    widget.onSkipped();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '就寝と起床の習慣を登録してください。',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          _TimeField(
            key: const Key('current-bedtime-field'),
            label: '現在の就寝時刻',
            value: _formatTime(_currentBedtime),
            onPressed: () => _pickTime(
              picker: widget.currentBedtimePicker,
              current: _currentBedtime,
              onChanged: (time) => _currentBedtime = time,
            ),
          ),
          _TimeField(
            key: const Key('current-wake-time-field'),
            label: '現在の起床時刻',
            value: _formatTime(_currentWakeTime),
            onPressed: () => _pickTime(
              picker: widget.currentWakeTimePicker,
              current: _currentWakeTime,
              onChanged: (time) => _currentWakeTime = time,
            ),
          ),
          _TimeField(
            key: const Key('ideal-bedtime-field'),
            label: '理想の就寝時刻',
            value: _formatTime(_idealBedtime),
            onPressed: () => _pickTime(
              picker: widget.idealBedtimePicker,
              current: _idealBedtime,
              onChanged: (time) => _idealBedtime = time,
            ),
          ),
          _TimeField(
            key: const Key('ideal-wake-time-field'),
            label: '理想の起床時刻',
            value: _formatTime(_idealWakeTime),
            onPressed: () => _pickTime(
              picker: widget.idealWakeTimePicker,
              current: _idealWakeTime,
              onChanged: (time) => _idealWakeTime = time,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '朝のルーティン候補',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...onboardingRoutineCandidates.map(
            (candidate) => CheckboxListTile(
              key: Key('routine-candidate-$candidate'),
              title: Text(candidate),
              value: _selectedRoutines.contains(candidate),
              onChanged: _saving
                  ? null
                  : (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedRoutines.add(candidate);
                        } else {
                          _selectedRoutines.remove(candidate);
                        }
                      });
                    },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('save-onboarding'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中...' : '保存して開始'),
          ),
          TextButton(
            key: const Key('skip-onboarding'),
            onPressed: _saving ? null : _skip,
            child: const Text('スキップ'),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(value, key: ValueKey(value)),
            ],
          ),
        ),
      ),
    );
  }
}
