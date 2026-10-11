import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../shared/account_sections.dart';
import '../../../shared/profile_sections.dart';
import '../../../shared/stitch.dart';
import '../../../shared/widgets.dart' show InlineError;
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';
import '../../../mock/demo_content.dart';

final riderProfileProvider = FutureProvider.autoDispose<RiderProfile>(
  (ref) => ref.watch(authRepositoryProvider).riderProfile(),
);

/// Wallet (Stitch `profile_wallet`). The only real piece is the rider's `default_payment_method`
/// (GET/PATCH me/rider, cash or card). There is no wallet balance, card vault or payment provider
/// (Vipps/BankID), so top-up, balance, saved cards and Vipps are intentionally absent. Saved
/// places are device-local.
class WalletTab extends ConsumerStatefulWidget {
  const WalletTab({super.key});

  @override
  ConsumerState<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<WalletTab> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // The CO2 estimate on the wallet card is derived from the real trip history.
    Future.microtask(
      () => ref.read(rideHistoryProvider.notifier).load(refresh: true),
    );
  }

  Future<void> _select(PaymentMethodType m) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateDefaultPaymentMethod(m.apiValue);
      ref.invalidate(riderProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${m.label} is now your default payment method.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final user = session is SessionAuthenticated ? session.user : null;
    final profile = ref.watch(riderProfileProvider);
    final current = PaymentMethodType.parse(
      profile.asData?.value.defaultPaymentMethod,
    );
    final loaded = profile.hasValue;
    return SingleChildScrollView(
      key: const Key('wallet_scroll'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileCard(
            user: user,
            nameKey: const Key('wallet_profile_name'),
            emailKey: const Key('wallet_profile_email'),
          ),
          const SizedBox(height: 24),
          const _WalletCard(),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeading(
                'Payment Methods',
              ),
              const SizedBox(height: 8),
              if (profile.hasError)
                InlineError(
                  message: 'Could not load your profile.',
                  onRetry: () => ref.invalidate(riderProfileProvider),
                ),
              ListCard(
                children: [
                  for (final m in PaymentMethodType.values)
                    IconRow(
                      key: Key('wallet_${m.apiValue}'),
                      icon: m == PaymentMethodType.cash
                          ? Symbols.payments
                          : Symbols.credit_card,
                      iconBackground: m == PaymentMethodType.cash
                          ? NordicColors.surfaceContainer
                          : NordicColors.primaryContainer.withValues(
                              alpha: 0.1,
                            ),
                      iconColor: m == PaymentMethodType.cash
                          ? NordicColors.onSurfaceVariant
                          : NordicColors.primary,
                      title: m.label,
                      subtitle: m == PaymentMethodType.cash
                          ? 'Pay the driver in person'
                          : 'Visa ending in 4242',
                      titleExtra: current == m && loaded
                          ? Container(
                              key: Key('wallet_default_${m.apiValue}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: NordicColors.secondary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: NordicText.labelSm.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : null,
                      onTap: _saving ? null : () => _select(m),
                      trailing: current == m && loaded
                          ? const MIcon(
                              Symbols.check_circle,
                              size: 24,
                              color: NordicColors.secondary,
                            )
                          : const MIcon(
                              Symbols.radio_button_unchecked,
                              size: 20,
                              color: NordicColors.outlineVariant,
                            ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SavedPlacesSection(keyPrefix: 'wallet'),
          const SizedBox(height: 24),
          const VersionLine(),
        ],
      ),
    );
  }
}

/// "Your rides" summary card (Stitch's wallet balance card without the balance: there is no wallet
/// service). Shows the real number of completed trips and the CO2 estimate derived from them.
class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref
        .watch(rideHistoryProvider)
        .rides
        .where((r) => r.status == RideStatus.completed)
        .toList();
    final completedTrips = completed.length;
    final distance = completed.fold<int>(0, (a, r) => a + r.distanceMeters);
    return Elevated(
      shadows: const [
        BoxShadow(
          color: Color(0x1F0F2A4A),
          blurRadius: 32,
          spreadRadius: -4,
          offset: Offset(0, 12),
        ),
      ],
      radius: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: const Key('wallet_balance_card'),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NordicColors.primaryContainer,
                NordicColors.primary,
                NordicColors.primaryContainer,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                bottom: -40,
                child: Blob(
                  size: 144,
                  color: NordicColors.secondaryFixedDim.withValues(alpha: 0.1),
                  blur: 40,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: NordicColors.secondary.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: MIcon(
                                    Symbols.electric_car,
                                    size: 20,
                                    color: NordicColors.secondaryFixed,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'YOUR RIDES',
                                  overflow: TextOverflow.ellipsis,
                                  style: NordicText.labelLg.copyWith(
                                    color: NordicColors.secondaryFixed,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 14 * 0.025,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Completed trips',
                              style: NordicText.labelMd.copyWith(
                                color: NordicColors.primaryFixedDim,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$completedTrips',
                              key: const Key('wallet_trips'),
                              style: NordicText.displayLgMobile.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 32 * -0.025,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'CO₂ Saved (est.)',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.primaryFixedDim,
                              ),
                            ),
                            Text(
                              '${co2SavedKg(distance)} kg',
                              key: const Key('wallet_co2'),
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.secondaryFixed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
