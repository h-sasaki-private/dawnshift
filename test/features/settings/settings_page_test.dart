import 'package:dawnshift/features/auth/auth_service.dart';
import 'package:dawnshift/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('SettingsPage', () {
    late AuthService authService;

    setUp(() async {
      PackageInfo.setMockInitialValues(
        appName: 'dawnshift',
        packageName: 'com.example.dawnshift',
        version: '1.2.3',
        buildNumber: '45',
        buildSignature: '',
      );
      final provider = FakeAuthProvider();
      authService = AuthService(provider: provider);
      await authService.registerWithEmail(
        email: 'test@example.com',
        password: 'Password123!',
      );
    });

    testWidgets('アプリバージョンとプライバシーポリシー導線を表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);
      expect(find.text('アプリバージョン'), findsOneWidget);
      expect(find.text('1.2.3+45'), findsOneWidget);
      expect(find.byKey(const Key('open-privacy-policy')), findsOneWidget);
      expect(find.byKey(const Key('delete-account')), findsOneWidget);
    });

    testWidgets('プライバシーポリシー画面へ遷移して内容を表示する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-privacy-policy')));
      await tester.pumpAndSettle();

      expect(find.text('プライバシーポリシー'), findsOneWidget);
      expect(find.textContaining('睡眠記録（就寝・起床時刻）'), findsOneWidget);
      expect(find.textContaining('Anthropic API（Claude）'), findsOneWidget);
      expect(find.textContaining('Firebase / Firestore'), findsOneWidget);
      expect(find.textContaining('アカウント削除で全データ削除'), findsOneWidget);
    });

    testWidgets('アカウント削除は確認ダイアログでキャンセルできる', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete-account')));
      await tester.pumpAndSettle();

      expect(find.text('アカウントを削除しますか？'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancel-delete-account')));
      await tester.pumpAndSettle();

      expect(authService.currentUser, isNotNull);
      expect(find.text('アカウントを削除しますか？'), findsNothing);
    });

    testWidgets('アカウント削除を確認すると deleteAccount を実行する', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsPage(authService: authService)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-account')));
      await tester.pumpAndSettle();

      expect(authService.currentUser, isNull);
      expect(find.text('アカウントを削除しました。'), findsOneWidget);
    });
  });
}
