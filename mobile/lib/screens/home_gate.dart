import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Not a visible screen. Decides where to send the user after a successful
/// login or OTP verification:
/// - Profile not completed → Profile screen (placeholder for now)
/// - Profile completed → Home screen (placeholder for now)
///
/// Phase 4 scope: we land on a simple placeholder with a "Log out" button
/// so you can exercise step 5 and 6 of the verification checklist.
class HomeGate extends StatelessWidget {
  static const routeName = '/home-gate';
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // In future phases this will navigate to Profile or Home.
    // For now: show a placeholder with a logout button.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '🎉 You are logged in!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appState.hasCompletedProfile
                    ? 'Profile complete — Home coming in a future phase.'
                    : 'Profile incomplete — Profile screen coming in a future phase.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),

              // ── Debug logout button ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  onPressed: () async {
                    await appState.logout();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  child: const Text('Log out (debug)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
