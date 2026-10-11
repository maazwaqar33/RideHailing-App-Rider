import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session_controller.dart';
import '../shared/nav_scaffold.dart';

/// Hosts the four tab branches inside the Stitch chrome (header + bottom navigation).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _labels = [
    'Ride Booking',
    'Activity Trips',
    'Wallet',
    'Profile',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return StitchNavScaffold(
      index: shell.currentIndex,
      onSelect: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      sectionLabel: _labels[shell.currentIndex],
      userName: session is SessionAuthenticated ? session.user.name : '',
      onAvatarTap: () => shell.goBranch(3),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(shell.currentIndex),
          child: shell,
        ),
      ),
    );
  }
}
