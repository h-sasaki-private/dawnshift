import 'package:dawnshift/features/ai_suggestion/anthropic_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_page.dart';
import 'features/onboarding/onboarding_app.dart';
import 'features/onboarding/onboarding_repository.dart';
import 'features/routine/routine_repository.dart';
import 'features/sleep/sleep_record_repository.dart';
import 'features/subscription/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await dotenv.load();
  } catch (_) {
    // .env がない場合は無視
  }
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key, this.repository, this.authService});

  final OnboardingRepository? repository;
  final AuthService? authService;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService =
        widget.authService ?? AuthService(provider: FirebaseAuthProvider());
  }

  Future<OnboardingRepository> _buildRepository(String uid) async {
    if (widget.repository != null) {
      return widget.repository!;
    }
    final localStore = await createSharedPreferencesStore();
    return OnboardingRepository(
      firestore: FirebaseFirestoreClient(),
      preferences: localStore,
      uid: uid,
    );
  }

  String _anthropicApiKey() {
    final value = dotenv.isInitialized
        ? dotenv.env['ANTHROPIC_API_KEY']?.trim()
        : null;
    return (value == null || value.isEmpty) ? 'disabled' : value;
  }

  String _revenueCatApiKey() {
    if (!dotenv.isInitialized) {
      return '';
    }
    return dotenv.env['REVENUECAT_API_KEY']?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dawnshift',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C6E71)),
      ),
      home: StreamBuilder<AppUser?>(
        stream: _authService.authStateChanges,
        initialData: _authService.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;

          // 未ログイン → ログイン画面
          if (user == null) {
            return LoginPage(authService: _authService);
          }

          // ログイン済み → リポジトリを構築してオンボーディングへ
          return FutureBuilder<OnboardingRepository>(
            future: _buildRepository(user.uid),
            builder: (context, repoSnapshot) {
              if (!repoSnapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final onboardingRepository = repoSnapshot.data!;
              final firestore =
                  widget.repository?.firestore ?? FirebaseFirestoreClient();
              final sleepRepository = SleepRecordRepository(
                store: firestore,
                uid: user.uid,
              );
              final routineRepository = RoutineRepository(
                store: firestore,
                uid: user.uid,
              );

              return OnboardingApp(
                repository: onboardingRepository,
                authService: _authService,
                sleepRepository: sleepRepository,
                routineRepository: routineRepository,
                anthropicClient: AnthropicApiClient(apiKey: _anthropicApiKey()),
                subscriptionService: RevenueCatSubscriptionService(
                  store: firestore,
                  preferences: onboardingRepository.preferences,
                  uid: user.uid,
                  apiKey: _revenueCatApiKey(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
