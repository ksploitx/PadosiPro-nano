// screens.dart — Phase 3/4 placeholder screens for features not yet built.
//
// LoginScreen, RegisterScreen, VerifyOtpScreen are now in their own files
// under screens/. Only non-auth placeholders live here.
import 'package:flutter/material.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  static const routeName = '/profile';
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderScreen(
      name: 'Profile Screen',
      navButtons: [
        _NavButton(
          label: 'Go to Task Selection',
          onTap: () =>
              Navigator.pushNamed(context, TaskSelectionScreen.routeName),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class TaskSelectionScreen extends StatelessWidget {
  static const routeName = '/task-selection';
  const TaskSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderScreen(
      name: 'Task Selection Screen',
      navButtons: [
        _NavButton(
          label: 'Go to Home',
          onTap: () => Navigator.pushNamed(context, HomeScreen.routeName),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PadosiPro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 14,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const Center(
        child: Text(
          'Home Screen',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            activeIcon: Icon(Icons.inbox),
            label: 'Request',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (_) {},
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Generic placeholder scaffold used by stub screens.
class _PlaceholderScreen extends StatelessWidget {
  final String name;
  final List<Widget> navButtons;

  const _PlaceholderScreen({
    required this.name,
    this.navButtons = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(name),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            ...navButtons,
          ],
        ),
      ),
    );
  }
}

/// Small tappable pill used for quick navigation testing.
class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 32),
      child: ElevatedButton(
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
