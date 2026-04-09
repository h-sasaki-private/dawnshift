import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:dawnshift/features/settings/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.authService});

  final AuthService? authService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  Future<void> _confirmDeleteAccount() async {
    final authService = widget.authService;
    if (authService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('認証情報がないためアカウント削除は利用できません。')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('アカウントを削除しますか？'),
          content: const Text('この操作は取り消せません。'),
          actions: [
            TextButton(
              key: const Key('cancel-delete-account'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('confirm-delete-account'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await authService.deleteAccount();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('アカウントを削除しました。')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('アプリ情報とプライバシー設定を確認できます。', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              title: const Text('アプリバージョン'),
              subtitle: FutureBuilder<PackageInfo>(
                future: _packageInfoFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('読み込み中...');
                  }

                  return Text(
                    '${snapshot.data!.version}+${snapshot.data!.buildNumber}',
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              key: const Key('open-privacy-policy'),
              title: const Text('プライバシーポリシー'),
              subtitle: const Text('収集データと利用目的を確認する'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            key: const Key('delete-account'),
            onPressed: _confirmDeleteAccount,
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('アカウントを削除'),
          ),
        ],
      ),
    );
  }
}
