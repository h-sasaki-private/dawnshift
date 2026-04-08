# dawnshift — Codex 向け実装ガイド

## 実装前チェックリスト

1. GitHub Issue の `## 完了条件` を必ず読め
2. 既存の関連ファイルを確認してから書き始めろ（`rg --files lib/ test/`）
3. テストを先に書け（Red → Green → Refactor）
4. `flutter test` で全テストが通ることを確認してからコミットせよ

---

## 環境

```bash
# flutter
/opt/homebrew/bin/flutter test test/features/<feature>/ --reporter expanded

# git / ブランチ作成
git checkout master && git pull origin master
git checkout -b feature/issue-{番号}-{概要}
```

- `~/.codex/config.toml` に `sandbox = "danger-full-access"` 設定済み
- git・flutter test・ネットワーク全て使用可能

---

## TDD原則

- テストはモジュールの**外部インターフェース**に対して書け（内部実装をテストしない）
- `expect(true).toBe(true)` のような意味のないアサーションは絶対に書くな
- テストを通すためだけのハードコードは禁止
- 境界値・異常系・エラーケースも必ずテストすること

---

## ファイル配置ルール

```
lib/core/models/        ← モデルクラスはここに置く（featuresに定義しない）
lib/features/<feature>/ ← UI・ロジック
test/features/<feature>/← テスト・FakeクラスはすべてここにおけIteスト用クラスをlib/に置くな）
```

---

## 実装パターン（過去の実装から）

### Firestoreアクセス
- `FirestoreInterface` を使い `FirebaseFirestoreClient`（本番）/ `FakeFirestore`（テスト）を差し替える
- コレクションパスは `users/{uid}/sleep_records` のように uid を含めること
- `FakeFirestore.query` のソートは `int` / `String` 両方に対応済み（`order` フィールド等）

### ダイアログの TextEditingController
- `showDialog` 内で `TextEditingController` を使う場合は **必ず `StatefulWidget` のダイアログクラスに移して `dispose()` を委譲**すること
- 外で `titleController.dispose()` を呼ぶと exit animation 中にクラッシュする

### ListView のウィジェットテスト
- テスト viewport（800×600）からはみ出すアイテムは `find.text()` で検出できない
- `tester.drag(find.byType(ListView), const Offset(0, -300))` でスクロールしてから検証すること

### 日付またぎ処理（睡眠記録）
- 就寝時刻 > 起床時刻の場合は `bedtime.subtract(const Duration(days: 1))` で前日扱いにする

---

## PR作成ルール

- **1 Issue = 1 PR**
- ブランチ名: `feature/issue-{番号}-{概要}`（例: `feature/issue-3-sleep-record`）
- PRの説明に必ず含めること:
  - `closes #{Issue番号}`
  - 実装内容の箇条書き
  - テスト結果（`N/N passed`）
- `flutter test` が全通過してからPRを作成すること

---

## 既実装の概要（参照用）

| ファイル | 概要 |
|---------|------|
| `lib/core/models/sleep_record.dart` | 睡眠記録モデル（`toJson`/`fromJson`、日付またぎバリデーション） |
| `lib/core/models/routine_item.dart` | ルーティン項目モデル（`order`フィールドあり） |
| `lib/core/models/routine_log.dart` | 完了率ログモデル |
| `lib/core/models/routine_suggestion.dart` | AI提案モデル（`RoutineItem`・`RoutineSuggestion`） |
| `lib/features/sleep/sleep_record_repository.dart` | Firestore CRUD + `FakeFirestore`（テスト用） |
| `lib/features/routine/routine_repository.dart` | ルーティンCRUD・デフォルトテンプレート投入・完了率ログ |
| `lib/features/auth/auth_service.dart` | Firebase Email/Password認証 + `FakeAuthProvider` |
| `lib/features/ai_suggestion/anthropic_client.dart` | Claude APIストリーミングクライアント |
| `lib/features/sleep/sleep_record_page.dart` | 睡眠記録入力・一覧・7日チャート UI |
| `lib/features/routine/routine_settings_page.dart` | ルーティン設定UI（追加・編集・削除） |
| `lib/features/routine/morning_routine_page.dart` | 朝の実行画面（チェックボックス・完了率） |
