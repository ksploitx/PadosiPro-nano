import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../services/api_client.dart';
import 'edit_details_screen.dart';
import 'household_placeholder_screen.dart';
import 'login_screen.dart';

/// Profile tab — matches figma/Setting.png.
///
/// Shows:
///   - Avatar header with name, mobile, email
///   - "Account & Personal Details" read-only card rows
///   - "Household & Family" section → placeholder screen
///   - "Edit Profile Details" button → EditDetailsScreen
///   - Logout button
///
/// States: loading → error-with-retry → populated   (HLD §6)
class ProfileTabScreen extends StatefulWidget {
  const ProfileTabScreen({super.key});

  @override
  State<ProfileTabScreen> createState() => _ProfileTabScreenState();
}

class _ProfileTabScreenState extends State<ProfileTabScreen> {
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final service = ProfileService(appState.apiClient);
      final profile = await service.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile. Check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be signed out of PadosiPro.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AppState>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      LoginScreen.routeName,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Image.asset(
          'assets/padosipro-logo.png',
          height: 36,
          errorBuilder: (_, __, ___) => const Text(
            'PadosiPro',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.primary,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _load);
    }

    return _ProfileContent(
      profile: _profile!,
      // prefer email from GET /profile (now included in response);
      // fall back to AppState cache for resilience
      email: _profile!.email ?? context.read<AppState>().email ?? '',
      onEditPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditDetailsScreen(profile: _profile!),
          ),
        );
        // Reload after returning from edit
        _load();
      },
      onHouseholdPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HouseholdPlaceholderScreen()),
      ),
      onLogout: _logout,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  final UserProfile profile;
  final String email;
  final VoidCallback onEditPressed;
  final VoidCallback onHouseholdPressed;
  final VoidCallback onLogout;

  const _ProfileContent({
    required this.profile,
    required this.email,
    required this.onEditPressed,
    required this.onHouseholdPressed,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile.name);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        // ── Avatar header card ───────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+91 ${profile.mobileNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Section: Account & Personal Details ──────────────────────────────
        const _SectionLabel('ACCOUNT & PERSONAL DETAILS'),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              _DetailRow(
                label: 'Your Name',
                value: profile.name,
                icon: Icons.badge_outlined,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _DetailRow(
                label: 'Mobile No',
                value: '+91 ${profile.mobileNumber}',
                icon: Icons.phone_outlined,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _DetailRow(
                label: 'Email',
                value: email.isNotEmpty ? email : '—',
                icon: Icons.mail_outline,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _DetailRow(
                label: 'Residence Address',
                value: profile.address,
                icon: Icons.location_on_outlined,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _DetailRow(
                label: 'Business / Firm',
                value: (profile.businessName?.isNotEmpty == true)
                    ? profile.businessName!
                    : 'Not specified (Optional)',
                valueItalic: profile.businessName?.isNotEmpty != true,
                icon: Icons.business_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Section: Household & Family ──────────────────────────────────────
        const _SectionLabel('HOUSEHOLD & FAMILY'),
        const SizedBox(height: 8),
        _HouseholdCard(onTap: onHouseholdPressed),
        const SizedBox(height: 28),

        // ── Edit Profile Details ─────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: onEditPressed,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit Profile Details'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Logout ───────────────────────────────────────────────────────────
        TextButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
          label: const Text(
            'Log out',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool valueItalic;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueItalic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: valueItalic ? AppColors.textHint : AppColors.textPrimary,
                    fontStyle: valueItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _HouseholdCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HouseholdCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.badgeBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.group_outlined, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Household',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Family members your LM should know',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Error / Retry state ───────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 32, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load profile',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
