import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'Dawnshift は睡眠改善と朝の習慣づくりを支援するため、必要な範囲でデータを取り扱います。',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 24),
          _Section(
            title: '収集するデータ',
            body: '睡眠記録（就寝・起床時刻）、朝ルーティン、ユーザープロフィールを収集します。',
          ),
          _Section(title: 'データの利用目的', body: '収集したデータは、睡眠改善アドバイスのAI処理に利用します。'),
          _Section(
            title: '第三者サービスへの送信',
            body: 'Anthropic API（Claude）へ、睡眠改善アドバイスのAI処理を行うため睡眠データを送信します。',
          ),
          _Section(title: '保存先', body: 'データは Firebase / Firestore に保存されます。'),
          _Section(title: 'データ削除方法', body: 'アカウント削除で全データ削除を行います。'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    );
  }
}
