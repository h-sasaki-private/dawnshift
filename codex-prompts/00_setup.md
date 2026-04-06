# Codex セットアップ用プロンプト（初回のみ実行）

## 実行方法
```bash
cd ~/dawnshift
codex < codex-prompts/00_setup.md
```

---

## プロンプト本文

あなたはFlutterアプリ "dawnshift" の開発者です。
AGENTS.md をよく読み、すべてのルールに従って作業してください。

以下を順番に実行してください。

### 1. Flutterプロジェクトの初期化

```bash
flutter create . --org com.example.dawnshift --project-name dawnshift --platforms ios,android
```

**重要**: 以下のファイルは既存のものを絶対に上書きしないこと。
- AGENTS.md
- CLAUDE.md
- lib/features/
- lib/core/
- test/features/

`flutter create` が既存ファイルを上書きしようとした場合は `--no-overwrite` オプションを使うか、
上書き対象ファイルをバックアップして復元すること。

### 2. pubspec.yaml への依存関係追加

`pubspec.yaml` の `dependencies` と `dev_dependencies` に以下を追加してください。

dependencies に追加:
```yaml
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  http: ^1.2.2
  flutter_dotenv: ^5.2.1
```

dev_dependencies に追加:
```yaml
  flutter_lints: ^4.0.0
```

### 3. .env ファイルの作成

```
ANTHROPIC_API_KEY=your_api_key_here
```

.gitignore に `.env` が含まれていることを確認すること。
含まれていない場合は追加すること。

### 4. 依存関係のインストール

```bash
flutter pub get
```

### 5. テストの実行

以下のテストをすべて実行し、結果を報告してください。

```bash
flutter test test/features/ai_suggestion/anthropic_client_test.dart
flutter test test/features/auth/auth_service_test.dart
flutter test test/features/sleep/sleep_record_repository_test.dart
flutter test test/features/routine/routine_repository_test.dart
```

テストが失敗した場合はエラー内容を確認し、**本番コードのみを修正**してテストを通してください。
テストコード自体は変更しないこと（ただし import パスのタイポ等の明らかな誤りは修正可）。

### 6. 完了報告

すべてのテストが通過したら以下を実行してください。

```bash
git add pubspec.yaml pubspec.lock .env.example .gitignore lib/ test/
git commit -m "chore: Flutter project setup with dependencies"
git push origin master
```
