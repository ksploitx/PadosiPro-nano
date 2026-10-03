import 'package:flutter/material.dart';
import '../theme.dart';

/// Placeholder – Phase 4 will replace body with real form fields.
class LoginScreen extends StatelessWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Login Screen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              // Quick-nav buttons so you can test routing in Phase 3
              _NavButton(
                label: 'Go to Register',
                onTap: () => Navigator.pushNamed(context, RegisterScreen.routeName),
              ),
              _NavButton(
                label: 'Go to Verify OTP',
                onTap: () => Navigator.pushNamed(
                  context,
                  VerifyOtpScreen.routeName,
                  arguments: 'test@example.com',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class RegisterScreen extends StatelessWidget {
  static const routeName = '/register';
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderScreen(
      name: 'Register Screen',
      navButtons: [
        _NavButton(
          label: 'Go to Verify OTP',
          onTap: () => Navigator.pushNamed(
            context,
            VerifyOtpScreen.routeName,
            arguments: 'test@example.com',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class VerifyOtpScreen extends StatelessWidget {
  static const routeName = '/verify-otp';
  const VerifyOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The real screen will read the email from route arguments.
    final email = ModalRoute.of(context)?.settings.arguments as String?;
    return _PlaceholderScreen(
      name: 'Verify OTP Screen',
      subtitle: email != null ? 'Email: $email' : null,
      navButtons: [
        _NavButton(
          label: 'Go to Profile',
          onTap: () => Navigator.pushNamed(context, ProfileScreen.routeName),
        ),
        _NavButton(
          label: 'Go to Home',
          onTap: () => Navigator.pushNamed(context, HomeScreen.routeName),
        ),
      ],
    );
  }
}

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

/// Generic placeholder scaffold used by all stub screens.
class _PlaceholderScreen extends StatelessWidget {
  final String name;
  final String? subtitle;
  final List<Widget> navButtons;

  const _PlaceholderScreen({
    required this.name,
    this.subtitle,
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
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 32),
            ...navButtons,
          ],
        ),
      ),
    );
  }
}

/// Small tappable pill used for Phase-3 screen navigation testing.
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

// Re-export route name references used in main.dart
// (import this file and access via LoginScreen.routeName etc.)
