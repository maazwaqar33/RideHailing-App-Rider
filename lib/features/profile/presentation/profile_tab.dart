import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../shared/account_sections.dart';
import '../../../shared/profile_sections.dart';
import '../../../shared/stitch.dart';
import '../../auth/application/session_controller.dart';

/// Profile: account info (from auth/me), saved places (device-local) and log out. Preferences,
/// data export and account deletion are intentionally absent (not built). Uses the same Stitch building blocks
/// as the Wallet tab (`profile_wallet`).
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to request rides.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            key: const Key('confirm_logout'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loggingOut = true);
    await ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final user = session is SessionAuthenticated ? session.user : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileCard(
            user: user,
            nameKey: const Key('profile_name'),
            emailKey: const Key('profile_email'),
          ),
          const SizedBox(height: 24),
          const SavedPlacesSection(keyPrefix: 'profile'),
          const SizedBox(height: 24),
          const SizedBox(height: 16),
          GestureDetector(
            key: const Key('logout'),
            onTap: _loggingOut ? null : _logout,
            child: Elevated(
              shadows: Tw.sm,
              radius: 8,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: NordicColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: _loggingOut
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MIcon(
                              Symbols.logout,
                              size: 20,
                              color: NordicColors.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Log out',
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const VersionLine(),
        ],
      ),
    );
  }
}
