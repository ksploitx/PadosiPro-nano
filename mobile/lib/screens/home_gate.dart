import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../services/profile_service.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'profile_screen.dart';
import 'tab_shell.dart';

/// Not a visible screen. Decides where to send the user after a successful
/// login or OTP verification:
///
///   GET /profile
///     → 404  : no profile yet  → Profile screen
///     → 200  : profile exists  → Phase 6 home (placeholder HomeScreen for now)
///
/// Phase 5 logic: this is the real routing gate. We do the network call here
/// so that if the user closed the app mid-onboarding we still recover to
/// the right step.
class HomeGate extends StatefulWidget {
  static const routeName = '/home-gate';
  const HomeGate({super.key});

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  @override
  void initState() {
    super.initState();
    // Run after first frame so Navigator is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final appState = context.read<AppState>();
    final service = ProfileService(appState.apiClient);

    try {
      await service.getProfile(); // 200 → profile exists
      // Profile complete → 3-tab shell
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, TabShell.routeName);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // No profile yet → create profile
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, ProfileScreen.routeName);
      } else {
        // Auth or network issue — retry handled by showing a re-login button
        if (!mounted) return;
        _showError(e.message);
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Network error. Please try again.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Splash while we wait for GET /profile to resolve.
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
