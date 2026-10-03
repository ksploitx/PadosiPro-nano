import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'theme.dart';
import 'services/api_client.dart';
import 'state/app_state.dart';
import 'screens/screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Build the shared singletons once and inject them via Provider.
  final apiClient = ApiClient();
  final appState = AppState(
    apiClient: apiClient,
    storage: const FlutterSecureStorage(),
  );

  // Restore any persisted JWT before the first frame.
  await appState.bootstrap();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const PadosiProApp(),
    ),
  );
}

class PadosiProApp extends StatelessWidget {
  const PadosiProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PadosiPro',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),

      // ── Initial route ────────────────────────────────────────────────────
      // Decides where to land based on whether the user is already logged in.
      initialRoute: _resolveInitialRoute(context),

      // ── Named routes ─────────────────────────────────────────────────────
      routes: {
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        VerifyOtpScreen.routeName: (_) => const VerifyOtpScreen(),
        ProfileScreen.routeName: (_) => const ProfileScreen(),
        TaskSelectionScreen.routeName: (_) => const TaskSelectionScreen(),
        HomeScreen.routeName: (_) => const HomeScreen(),
      },
    );
  }

  /// Returns the correct initial route without calling [context.watch] so this
  /// is a one-shot read at startup (bootstrap() has already finished).
  String _resolveInitialRoute(BuildContext context) {
    final state = context.read<AppState>();
    if (!state.isLoggedIn) return LoginScreen.routeName;
    if (!state.hasCompletedProfile) return ProfileScreen.routeName;
    return HomeScreen.routeName;
  }
}
