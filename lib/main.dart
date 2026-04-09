import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'features/auth/auth_service.dart';
import 'features/onboarding/onboarding_app.dart';
import 'features/onboarding/onboarding_repository.dart';
import 'features/sleep/sleep_record_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  Future<OnboardingRepository>? _repositoryFuture;

  @override
  void initState() {
    super.initState();
    _repositoryFuture = widget.repository != null
        ? Future<OnboardingRepository>.value(widget.repository)
        : _buildRepository();
  }

  Future<OnboardingRepository> _buildRepository() async {
    final localStore = await createSharedPreferencesStore();
    final profileId =
        localStore.getString('onboarding_profile_id') ??
        'profile-${DateTime.now().millisecondsSinceEpoch}';

    if (localStore.getString('onboarding_profile_id') == null) {
      await localStore.setString('onboarding_profile_id', profileId);
    }

    return OnboardingRepository(
      firestore: FirebaseFirestoreClient(),
      preferences: localStore,
      uid: profileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OnboardingRepository>(
      future: _repositoryFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        return MaterialApp(
          title: 'dawnshift',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3C6E71),
            ),
          ),
          home: OnboardingApp(
            repository: snapshot.data!,
            authService:
                widget.authService ??
                AuthService(provider: FirebaseAuthProvider()),
          ),
        );
      },
    );
  }
}
