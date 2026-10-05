import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import 'home_gate.dart';

/// Route argument: the email string passed from RegisterScreen / LoginScreen.
class VerifyOtpScreen extends StatefulWidget {
  static const routeName = '/verify-otp';
  const VerifyOtpScreen({super.key});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  static const _digitCount = 6;
  static const _resendCooldown = 30;

  late final String _email;
  bool _emailResolved = false;

  final List<String> _digits = List.filled(_digitCount, '');
  int _focusedIndex = 0;

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  int _secondsLeft = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_emailResolved) {
      _email =
          (ModalRoute.of(context)?.settings.arguments as String?) ?? '';
      _emailResolved = true;
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _code => _digits.join();

  void _onKeyTap(String key) {
    if (key == '⌫') {
      // backspace
      int idx = _focusedIndex;
      if (_digits[idx].isNotEmpty) {
        setState(() => _digits[idx] = '');
      } else if (idx > 0) {
        setState(() {
          _focusedIndex = idx - 1;
          _digits[_focusedIndex] = '';
        });
      }
      return;
    }

    if (_focusedIndex >= _digitCount) return;
    setState(() {
      _digits[_focusedIndex] = key;
      if (_focusedIndex < _digitCount - 1) _focusedIndex++;
    });

    // Auto-submit once all 6 digits entered
    if (_code.length == _digitCount) {
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_code.length < _digitCount) {
      setState(() => _errorMessage = 'Enter all 6 digits');
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final appState = context.read<AppState>();
    final authService = AuthService(appState.apiClient);

    try {
      final result = await authService.verifyOtp(email: _email, code: _code);
      await appState.saveToken(
        result.accessToken,
        hasCompletedProfile: result.hasCompletedProfile,
        email: _email,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, HomeGate.routeName);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        // Reset digits on hard errors so user can retype
        if (e.statusCode == 429 || e.message.contains('expired')) {
          _digits.fillRange(0, _digitCount, '');
          _focusedIndex = 0;
        }
      });
    } catch (_) {
      setState(() => _errorMessage = 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final appState = context.read<AppState>();
    final authService = AuthService(appState.apiClient);

    try {
      await authService.resendOtp(email: _email);
      _startCountdown();
      setState(() {
        _digits.fillRange(0, _digitCount, '');
        _focusedIndex = 0;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Edit mail — goes back to register
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back,
                              size: 14, color: AppColors.textSecondary),
                          SizedBox(width: 4),
                          Text(
                            'Edit mail',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Verify mail badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.badgeBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle,
                            size: 8, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Verify mail',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // ── Envelope icon ────────────────────────────────────
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.badgeBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.mail_outline_rounded,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Heading ──────────────────────────────────────────
                    const Text(
                      'Verify your email',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We sent a 6-digit code to',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _emailResolved ? _email : '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Error banner ─────────────────────────────────────
                    if (_errorMessage != null) ...[
                      _ErrorBanner(message: _errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // ── 6-box OTP input ───────────────────────────────────
                    // Bug 3: compute responsive box width so all 6 digits fit
                    // regardless of screen size, no overflow stripe.
                    Builder(builder: (context) {
                      final screenWidth =
                          MediaQuery.of(context).size.width;
                      // 48px total side padding (24 each) + 8px gaps (4px × 2 × 6 boxes)
                      final boxWidth = ((screenWidth - 48 - 48) / _digitCount)
                          .clamp(36.0, 52.0);
                      return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_digitCount, (i) {
                        final isFocused = i == _focusedIndex;
                        final hasValue = _digits[i].isNotEmpty;
                        return GestureDetector(
                          onTap: () => setState(() => _focusedIndex = i),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: boxWidth,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFocused
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: isFocused ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: hasValue
                                ? Text(
                                    _digits[i],
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  )
                                : isFocused
                                    ? Container(
                                        width: 2,
                                        height: 22,
                                        color: AppColors.primary,
                                      )
                                    : Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.divider,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                          ),
                        );
                      }),
                      );
                    }),
                    const SizedBox(height: 10),

                    // ── Security note ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.shield_outlined,
                            size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          'End-to-end encrypted session',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Verify button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : _verify,
                        child: _isVerifying
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
                                  Text('Verify'),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Resend countdown ──────────────────────────────────
                    _isResending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : GestureDetector(
                            onTap: _secondsLeft == 0 ? _resend : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: _secondsLeft > 0
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _secondsLeft > 0
                                      ? 'Resend code in ${_secondsLeft}s'
                                      : 'Resend code',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _secondsLeft == 0
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _secondsLeft > 0
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Custom numeric keypad ─────────────────────────────────────
            _NumericKeypad(onKeyTap: _onKeyTap),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom numeric keypad (matches Figma)
// ─────────────────────────────────────────────────────────────────────────────

class _NumericKeypad extends StatelessWidget {
  final void Function(String key) onKeyTap;

  const _NumericKeypad({required this.onKeyTap});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: keys.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) return const Expanded(child: SizedBox());
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _KeyButton(
                    label: key,
                    onTap: () => onKeyTap(key),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBackspace = label == '⌫';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isBackspace
            ? const Icon(Icons.backspace_outlined,
                size: 20, color: AppColors.textSecondary)
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
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
