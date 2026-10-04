import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';

/// Edit Details screen — matches figma/Edit_Details.png with simplifications:
///   - Avatar = static initials placeholder (no image picker)
///   - Mobile-number verified/not-verified status pill removed (just the field)
///   - Email shown as read-only (not in PUT /profile, displayed from AppState)
///   - "Save Changes" → PUT /profile
///
/// States: idle, submitting, error banner  (HLD §6)
class EditDetailsScreen extends StatefulWidget {
  final UserProfile profile;
  const EditDetailsScreen({super.key, required this.profile});

  @override
  State<EditDetailsScreen> createState() => _EditDetailsScreenState();
}

class _EditDetailsScreenState extends State<EditDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _businessCtrl;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl     = TextEditingController(text: widget.profile.name);
    _mobileCtrl   = TextEditingController(text: widget.profile.mobileNumber);
    _addressCtrl  = TextEditingController(text: widget.profile.address);
    _businessCtrl = TextEditingController(text: widget.profile.businessName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _businessCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final appState = context.read<AppState>();
      final service = ProfileService(appState.apiClient);

      await service.saveProfile(
        UserProfile(
          name: _nameCtrl.text.trim(),
          mobileNumber: _mobileCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          businessName: _businessCtrl.text.trim().isEmpty
              ? null
              : _businessCtrl.text.trim(),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } on Exception catch (e) {
      setState(() {
        _error = e.toString().replaceAll(RegExp(r'ApiException\(\d+\): '), '');
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<AppState>().email ?? '';
    final initials = _initials(widget.profile.name);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text(
          'Edit Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar (static placeholder, no upload) ──────────────────
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: AppColors.badgeBackground,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Profile Photo',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Error banner ────────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Full Name ────────────────────────────────────────────────
                _label('Full Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Rahul Sharma'),
                  validator: (v) {
                    if ((v?.trim().length ?? 0) < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Mobile Number ────────────────────────────────────────────
                _label('Mobile Number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '98765 43210',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('🇮🇳', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 6),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            height: 20,
                            child: VerticalDivider(color: AppColors.divider, thickness: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v?.trim() ?? '')) {
                      return 'Enter a valid 10-digit Indian mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Email (read-only from AppState) ──────────────────────────
                _label('Email Address'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          email.isNotEmpty ? email : '—',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Residence Address ────────────────────────────────────────
                _label('Residence Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressCtrl,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Flat / House No., Building, Street, Area',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) {
                    if ((v?.trim().length ?? 0) < 5) return 'Address must be at least 5 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Business name (optional) ──────────────────────────────────
                _label('Business name (optional)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _businessCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Acme Enterprises'),
                ),
                const SizedBox(height: 40),

                // ── Save Changes button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
  );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
