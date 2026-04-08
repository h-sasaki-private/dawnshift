# dawnshift — Claude Code 向け開発ガイド

## プロジェクト概要

睡眠改善・朝ルーティン管理Flutterアプリ。
毎晩AIが翌日の就寝目標と朝ルーティンを提案し、「起きる理由」を作る。

- **Flutter**（iOS / Android）
- **Firebase Auth / Firestore**
- **Anthropic API**（Claude）
- **RevenueCat**（サブスク管理）

---

## 開発フロー

### Codex × Claude Code の役割分担

| 役割 | 担当 |
|------|------|
| Issue実装・テスト作成 | Codex（`codex:rescue` スキル） |
| PRレビュー・修正指摘 | Claude Code |
| git操作・テスト実行・push | Claude Code（Codexがサンドボックスで詰まった場合） |
| マージ・進捗管理 | Claude Code |

### Codex呼び出し方法

```
/codex:rescue で指示を投げる
```

- `~/.codex/config.toml` に `sandbox = "danger-full-access"` 設定済み
- git操作・`flutter test`・ネットワーク全て使用可能
- それでも詰まった場合はClaudeが直接引き継ぐ

### flutter テスト実行

```bash
/opt/homebrew/bin/flutter test test/features/<feature>/ --reporter expanded
```

---

## TDD原則

- コードを書く前に必ずテストを書け（Red → Green → Refactor）
- テストはモジュールの**外部インターフェース**に対して書け（内部実装をテストしない）
- 1つのIssue着手前にテストファイルを先に作成せよ
- テストが通ってから次のフェーズに進む

### テストコードの品質

- テストは必ず実際の機能を検証すること
- `expect(true).toBe(true)` のような意味のないアサーションは絶対に書かない
- 各テストケースは具体的な入力と期待される出力を検証すること
- モックは必要最小限にとどめ、実際の動作に近い形でテストすること
- 境界値・異常系・エラーケースも必ずテストすること

### ハードコーディングの禁止

- テストを通すためだけのハードコードは絶対に禁止
- 本番コードに `if (testMode)` のような条件分岐を入れない
- APIキー・シークレットをコードに直接書かない（`.env` または環境変数を使用）

---

## ディレクトリ構成

```
lib/
├── main.dart
├── app/
│   └── app.dart               # ルーティング・テーマ設定
├── features/
│   ├── auth/                  # Issue #2: Firebase認証
│   ├── sleep/                 # Issue #3: 睡眠記録
│   ├── routine/               # Issue #4: 朝ルーティン
│   ├── ai_suggestion/         # Issue #1・#5: AI提案
│   └── onboarding/            # Issue #6: オンボーディング
├── core/
│   ├── services/              # Firebase・API クライアント
│   ├── models/                # Firestoreデータモデル
│   └── utils/
test/
├── features/
│   └── （各featureに対応したテスト）
```

---

## Firestoreデータ構造

```
users/{uid}/
  ├── profile          # オンボーディング入力・設定
  ├── sleep_records/   # 睡眠記録（就寝・起床時刻）
  ├── routines/        # ルーティン項目定義
  └── routine_logs/    # 日次完了ログ
```

- セキュリティルール：ユーザーは自分の `users/{uid}` 配下のみアクセス可

---

## AIプロンプト方針（Issue #1・#5）

- システムプロンプトに厚労省「健康づくりのための睡眠ガイド2023」の要点を含めること
- レスポンスはJSON構造化出力を使い、Dartでパースしやすい形式にすること
- APIキーは環境変数 `ANTHROPIC_API_KEY` から取得すること
- レイテンシ目標：3秒以内（ストリーミング開始時刻を基準）

---

## フリーミアム制御（Issue #7）

| 機能 | 無料 | 有料 |
|------|------|------|
| 睡眠記録 | ✅ | ✅ |
| 基本ルーティン設定 | ✅（上限あり） | ✅（無制限） |
| AIアドバイス | ❌ | ✅ |
| 週次レポート | ❌ | ✅ |

- サブスク状態は RevenueCat SDK から取得し Firestore に同期すること

---

## Issue依存関係

```
#1 Anthropic API ─┐
#2 Firebase DB   ─┼─→ #5 AI提案 → #7 フリーミアム → #8 ストア申請
#3 睡眠記録  ←#2─┤
#4 朝ルーティン←#2┘
#3・#4完了 ─→ #6 オンボーディング
```

---

## Issue進捗（2026-04-08時点）

| Issue | ブランチ | PR | 状態 |
|-------|----------|----|------|
| #1 Anthropic API | `feature/issue-1-anthropic-api` | #9 | ✅ マージ済み |
| #2 Firebase DB | `feature/issue-2-firebase-auth-db` | #10 | ✅ マージ済み |
| #3 睡眠記録 | `feature/issue-3-sleep-record` | #11 | レビュー待ち |
| #4 朝ルーティン | `feature/issue-4-routine` | #12 | レビュー待ち |
| #5 AI提案 | 未着手 | - | #1・#2マージ済みのため着手可 |
| #6 オンボーディング | 未着手 | - | #3・#4完了後 |
| #7 フリーミアム | 未着手 | - | #5完了後 |
| #8 ストア申請 | 未着手 | - | #7完了後 |

---

## 実装済みの設計決定事項

### ファイル配置
- **モデルクラス**: `lib/core/models/` に置くこと（`features/` 内に定義しない）
- **テスト用クラス**: `MockHttpClient` / `FakeFirestore` 等は `lib/` ではなく `test/` に置くこと

### Firestore
- **`_withId`**: `{'id': snapshot.id, ...data}` の順にスプレッドし、ドキュメントデータの `id` フィールドを保護すること
- **`query` の `afterDate`**: `orderByField` が null のとき `afterDate` は無視される。assert済みだが呼び出し側で必ず両方指定すること
- **`FakeFirestore.query` のソート**: `orderByField` の値が `int` の場合も正しくソートできるよう `num` 型チェックが必要（`order` フィールド等）

### Flutter UI
- **`TextEditingController` のライフサイクル**: `showDialog` 内で使う場合は `StatefulWidget` のダイアログクラスに移して `dispose()` を委譲すること。`showDialog` の future は exit animation 完了前に resolve するため、外で `dispose()` するとクラッシュする
- **ListView のウィジェットテスト**: テスト viewport（800×600）からはみ出すアイテムは `find.text()` で検出できない。`tester.drag` でスクロールしてから検証すること

### PR・ブランチ管理
- 同一の祖先コミットから分岐した複数PRは `lib/main.dart` 等で競合が発生する。依存関係の順にマージし、後のブランチは `git rebase origin/master` すること
