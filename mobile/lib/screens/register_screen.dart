import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import 'login_screen.dart';
import 'verify_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  static const routeName = '/register';
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  /// 0–3: weak, medium, strong
  int _passwordStrength = 0;

  void _updateStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Za-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    setState(() => _passwordStrength = score);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appState = context.read<AppState>();
    final authService = AuthService(appState.apiClient);

    try {
      final email = await authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        VerifyOtpScreen.routeName,
        arguments: email,
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo + Wordmark ────────────────────────────────────────
                _LogoWordmark(),
                const SizedBox(height: 20),

                // ── Heading ────────────────────────────────────────────────
                const Text(
                  'Create your account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "You don't manage tasks — we do.",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Feature card ────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.badgeBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.headset_mic_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dedicated Lifestyle Desk',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Private on-demand assistance across India',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Error banner ───────────────────────────────────────────
                if (_errorMessage != null) ...[
                  _ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 16),
                ],

                // ── Email ──────────────────────────────────────────────────
                const _FieldLabel('Email'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    hintText: 'e.g. alex@example.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(v.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password ───────────────────────────────────────────────
                const _FieldLabel('Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  onChanged: _updateStrength,
                  decoration: InputDecoration(
                    hintText: 'Min 8 chars, letters + numbers',
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 8) return 'At least 8 characters';
                    if (!v.contains(RegExp(r'[A-Za-z]'))) {
                      return 'Include at least one letter';
                    }
                    if (!v.contains(RegExp(r'[0-9]'))) {
                      return 'Include at least one number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),

                // ── Password strength bar ──────────────────────────────────
                _PasswordStrengthBar(strength: _passwordStrength),
                const SizedBox(height: 16),

                // ── Confirm password ───────────────────────────────────────
                const _FieldLabel('Confirm password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Re-enter your password',
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm password';
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Create account button ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Create account'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Already have an account ────────────────────────────────
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                            context, LoginScreen.routeName),
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength; // 0,1,2,3

  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final labels = ['', 'Weak', 'Good security', 'Strong'];
    final colors = [
      Colors.transparent,
      const Color(0xFFE53E3E),
      AppColors.primary,
      const Color(0xFF2E7D32),
    ];

    return Row(
      children: [
        // 3 segments
        for (int i = 1; i <= 3; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: strength >= i ? colors[strength] : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: 8),
        // label
        Text(
          strength > 0 ? labels[strength] : '',
          style: TextStyle(
            fontSize: 12,
            color: strength > 0 ? colors[strength] : Colors.transparent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets (duplicated here so each screen file is self-contained)
// ─────────────────────────────────────────────────────────────────────────────

class _LogoWordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/logo.png',
            width: 52,
            height: 52,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'PadosiPro',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
