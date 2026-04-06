# Issue #1: Anthropic API接続検証

## 実行方法
```bash
cd ~/dawnshift
codex < codex-prompts/01_anthropic_api.md
```

---

## プロンプト本文

あなたはFlutterアプリ "dawnshift" の開発者です。
AGENTS.md をよく読み、すべてのルールに従って作業してください。

GitHub の Issue #1「Anthropic API接続検証」を実装します。

### 完了条件（必ず達成すること）
- APIからルーティン提案が返ること
- レイテンシ3秒以内（ストリーミング開始時刻を基準）

### 作業手順

#### Step 1: テストの確認（Redフェーズ）

まず現在のテスト状態を確認してください。

```bash
flutter test test/features/ai_suggestion/anthropic_client_test.dart --reporter expanded
```

失敗しているテストを確認し、何を実装すべきか把握してください。

#### Step 2: 実装（Greenフェーズ）

`lib/features/ai_suggestion/anthropic_client.dart` を確認してください。
テストがすべて通るよう、不足している実装を追加・修正してください。

**実装上の制約**:
- APIキーは必ず環境変数 `ANTHROPIC_API_KEY` から取得すること（flutter_dotenv 使用）
- APIキーをコードにハードコードしないこと
- ストリーミングAPIを使用すること（`stream: true`）
- レスポンスは以下のJSON形式で返すこと:
  ```json
  {
    "target_bedtime": "HH:MM",
    "routines": [
      {"title": "ルーティン名", "duration_minutes": 10}
    ]
  }
  ```
- システムプロンプトに厚労省「健康づくりのための睡眠ガイド2023」の要点を含めること

#### Step 3: テスト通過の確認

```bash
flutter test test/features/ai_suggestion/anthropic_client_test.dart --reporter expanded
```

すべて PASS になるまで修正を繰り返すこと。

#### Step 4: ブランチ作成とPR

すべてのテストが通過したら以下を実行してください。

```bash
git checkout -b feature/issue-1-anthropic-api
git add lib/features/ai_suggestion/
git commit -m "feat: Anthropic APIクライアントの最小実装 (#1)

- ストリーミングAPIによるルーティン提案取得
- 厚労省睡眠ガイドライン2023をシステムプロンプトに組み込み
- APIキーを環境変数から取得
- レイテンシ3秒以内の検証テスト追加"
git push origin feature/issue-1-anthropic-api
```

PRを作成してください:
```bash
gh pr create \
  --title "feat: Anthropic API接続検証 (#1)" \
  --body "## 対応Issue
closes #1

## 実装内容
- AnthropicClientクラスによるストリーミングAPI呼び出し
- 厚労省「健康づくりのための睡眠ガイド2023」をシステムプロンプトに組み込み
- APIキーは環境変数 ANTHROPIC_API_KEY から取得（flutter_dotenv）
- RoutineSuggestionモデルによるJSONパース

## テスト結果
- [ ] anthropic_client_test.dart 全テスト通過
- [ ] レイテンシ3秒以内を確認

## 技術的な判断
- ストリーミングレスポンスを使用し初回チャンクまでの時間を計測
- MockHttpClientでネットワーク層をモックし単体テストを実現"
```
