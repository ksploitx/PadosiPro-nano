import 'package:flutter/material.dart';

import '../theme.dart';
import 'tab_shell.dart';

/// Shared app bar used by all three tab screens (Home, Request, Profile).
///
/// Layout:  [logo icon 36×36]  ···  [avatar → Profile tab]
///
/// Rules:
///   • No wordmark text — icon only.
///   • Tapping the avatar circle switches to the Profile tab (index 2) via
///     TabShell.of(context), NOT by pushing a new route.
PreferredSizeWidget buildAppHeader({
  List<Widget> extraActions = const [],
}) {
  return _AppHeader(extraActions: extraActions);
}

class _AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> extraActions;
  const _AppHeader({this.extraActions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/logo.png',
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.home_work_outlined,
                color: Colors.white, size: 20),
          ),
        ),
      ),
      actions: [
        ...extraActions,
        // Avatar → switches to Profile tab (no new route pushed)
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: () {
              final shell = TabShell.of(context);
              shell.switchTab(2);
            },
            child: const CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
