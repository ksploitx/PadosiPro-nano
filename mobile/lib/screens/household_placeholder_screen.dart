import 'package:flutter/material.dart';
import '../theme.dart';

/// Household screen — placeholder (Phase 6 simplification).
///
/// The real Household page (figma/Household_page.png) requires a data model
/// and family-member backend that are out of scope for v1. This screen just
/// shows a "Coming soon" message so the route doesn't crash.
class HouseholdPlaceholderScreen extends StatelessWidget {
  const HouseholdPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text(
          'Household',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.badgeBackground,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Coming soon',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Add the people (and pets) in your household\nso your Lifestyle Manager has the full picture.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
