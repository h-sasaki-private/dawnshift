# Issue #2: Firebase認証＋DB設計

## 実行方法
```bash
cd ~/dawnshift
codex < codex-prompts/02_firebase_auth_db.md
```

**前提**: Firebase コンソールでプロジェクトを作成し、
`flutterfire configure` を実行して `firebase_options.dart` を生成済みであること。

---

## プロンプト本文

あなたはFlutterアプリ "dawnshift" の開発者です。
AGENTS.md をよく読み、すべてのルールに従って作業してください。

GitHub の Issue #2「Firebase認証＋DB設計」を実装します。

### 完了条件（必ず達成すること）
- ユーザー登録・ログインが動作すること
- 睡眠記録・ルーティンデータの読み書きができること

### 作業手順

#### Step 1: テストの確認（Redフェーズ）

```bash
flutter test test/features/auth/auth_service_test.dart --reporter expanded
flutter test test/features/sleep/sleep_record_repository_test.dart --reporter expanded
flutter test test/features/routine/routine_repository_test.dart --reporter expanded
```

#### Step 2: 実装（Greenフェーズ）

以下のファイルを確認し、テストがすべて通るよう実装してください。

- `lib/features/auth/auth_service.dart`
- `lib/features/sleep/sleep_record_repository.dart`
- `lib/features/routine/routine_repository.dart`
- `lib/core/models/sleep_record.dart`
- `lib/core/models/routine_item.dart`

**実装上の制約**:

**認証**:
- Firebase Auth の Email/Password 認証を使用すること
- `AuthProvider` の本番実装（`FirebaseAuthProvider`）を `auth_service.dart` に追加すること
- テストでは `FakeAuthProvider` を使い、Firebase への実際の接続は不要

**Firestore**:
- `FirestoreInterface` の本番実装（`FirebaseFirestoreClient`）を追加すること
- コレクションパスは必ず `users/{uid}/...` の形式にすること（セキュリティルール準拠）
- テストでは `FakeFirestore` を使い、実際のFirestoreへの接続は不要

**セキュリティルール**:
`firestore.rules` ファイルを作成してください:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

#### Step 3: main.dart の更新

`lib/main.dart` を更新し、Firebase を初期化してください:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const App());
}
```

#### Step 4: テスト通過の確認

```bash
flutter test test/features/auth/ test/features/sleep/ test/features/routine/ --reporter expanded
```

すべて PASS になるまで修正を繰り返すこと。

#### Step 5: ブランチ作成とPR

```bash
git checkout -b feature/issue-2-firebase-auth-db
git add lib/ test/ firestore.rules
git commit -m "feat: Firebase認証・Firestoreリポジトリの最小実装 (#2)

- AuthService: Email/Password認証（FakeAuthProvider でテスト可能）
- SleepRecordRepository: 睡眠記録のCRUD + 過去7日取得
- RoutineRepository: ルーティン項目のCRUD
- Firestoreセキュリティルール: users/{uid} 配下のみアクセス可
- 全モデルのJSON シリアライズ対応"
git push origin feature/issue-2-firebase-auth-db
```

```bash
gh pr create \
  --title "feat: Firebase認証＋DB設計 (#2)" \
  --body "## 対応Issue
closes #2

## 実装内容
- AuthService: Firebase Email/Password認証（AuthProviderで本番/テスト切替可能）
- SleepRecordRepository: Firestoreへの睡眠記録CRUD・過去7日取得
- RoutineRepository: Firestoreへのルーティン項目CRUD
- SleepRecord・RoutineItemモデル（バリデーション付き）
- Firestoreセキュリティルール（users/{uid}配下のみ許可）

## テスト結果
- [ ] auth_service_test.dart 全テスト通過
- [ ] sleep_record_repository_test.dart 全テスト通過
- [ ] routine_repository_test.dart 全テスト通過

## 技術的な判断
- FakeAuthProvider / FakeFirestore により Firebase 接続なしで単体テスト可能
- コレクションパスに uid を含めることでセキュリティルールと整合"
```
