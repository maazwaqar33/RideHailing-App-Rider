import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../mock/demo_content.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import 'trip_widgets.dart';
import '../../auth/application/session_controller.dart';
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';
import '../application/trip_providers.dart';
import '../domain/trip_models.dart';
import 'report_problem_sheet.dart';

/// Trip completed (Stitch `trip_complete_receipt`): real fare breakdown from the ride,
/// MOCK payment confirmation, optional MOCK tip, rating + tags + note stored on the device only
/// (NOT sent to the backend).
///
/// Not in the API, so omitted or replaced: driver rating (4.98), "100% zero-emission",
/// airport toll, Vipps/BankID verification, PDF export.
class TripCompleteScreen extends ConsumerStatefulWidget {
  const TripCompleteScreen({super.key, required this.rideId});

  final int rideId;

  @override
  ConsumerState<TripCompleteScreen> createState() => _TripCompleteScreenState();
}

class _TripCompleteScreenState extends ConsumerState<TripCompleteScreen> {
  int _rating = 0;
  final _tags = <String>{};
  final _comment = TextEditingController();
  int _tipMinor = 0;
  bool _busy = false;
  bool _paying = false;
  PaymentReceipt? _receipt;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final existing = await ref
        .read(paymentServiceProvider)
        .receiptFor(widget.rideId);
    final feedback = await ref
        .read(feedbackRepositoryProvider)
        .get(widget.rideId);
    if (!mounted) return;
    setState(() {
      _receipt = existing;
      if (feedback != null) {
        _rating = feedback.rating;
        _tags.addAll(feedback.tags);
        _comment.text = feedback.comment;
        _tipMinor = feedback.tipMinor;
        _submitted = true;
      }
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<PaymentReceipt> _confirmPayment(Ride ride) async {
    final method = PaymentMethodType.parse(ride.payment.method);
    final receipt = await ref
        .read(paymentServiceProvider)
        .confirm(ride: ride, method: method, tipMinor: _tipMinor);
    if (mounted) setState(() => _receipt = receipt);
    return receipt;
  }

  Future<void> _done(Ride ride) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_receipt == null) await _confirmPayment(ride);
      if (_rating > 0 && !_submitted) {
        await ref
            .read(feedbackRepositoryProvider)
            .save(
              RideFeedback(
                rideId: ride.id,
                rating: _rating,
                comment: _comment.text.trim(),
                tags: _tags.toList(),
                tipMinor: _tipMinor,
              ),
            );
        ref.invalidate(savedFeedbackProvider(ride.id));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _rating > 0
                ? 'Thank you for your rating!'
                : 'Done.',
          ),
        ),
      );
      ref.invalidate(activeRideProvider);
      context.go('/home');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _customTip(String currency) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom tip'),
        content: TextField(
          key: const Key('custom_tip_field'),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            prefixText:
                '${Money.format(0, currency).replaceAll(RegExp(r'[0-9.,\s]'), '')} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(
                ctx,
                v == null || v < 0 || v > 500 ? null : (v * 100).round(),
              );
            },
            child: const Text('Set tip'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) setState(() => _tipMinor = result);
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(rideDetailProvider(widget.rideId));
    final session = ref.watch(sessionControllerProvider);
    final userName = session is SessionAuthenticated ? session.user.name : null;
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Column(
        children: [
          StitchBackHeader(
            title: 'Trip Receipt Details',
            onBack: () => context.go('/home'),
            showLogo: true,
            iosBack: true,
            userName: userName,
          ),
          Expanded(
            child: rideAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    NordicSkeletonRow(),
                    NordicSkeletonRow(),
                    NordicSkeletonRow(),
                  ],
                ),
              ),
              error: (e, _) => NordicErrorView(
                message: 'We could not load your trip.',
                onRetry: () =>
                    ref.invalidate(rideDetailProvider(widget.rideId)),
              ),
              data: _content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(Ride ride) {
    final currency = ride.fare.currency;
    final method = PaymentMethodType.parse(ride.payment.method);
    final b = ride.fare.breakdown;
    final total = ride.fare.finalMinor ?? ride.fare.estimateMinor ?? 0;
    final driverName = ride.driver?.firstName ?? 'your driver';
    final vehicle = ride.vehicle;
    final presetIndex = kTipPresetsMinor.indexOf(_tipMinor);
    final tipIndex = presetIndex >= 0 ? presetIndex : kTipPresetsMinor.length;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                Elevated(
                  shadows: Tw.md,
                  circle: true,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: NordicColors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: MIcon(
                        Symbols.check,
                        size: 36,
                        weight: 700,
                        color: NordicColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MIcon(
                        Symbols.eco,
                        size: 14,
                        lh: 20,
                        color: NordicColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '100% Zero-Emission Ride',
                        key: const Key('complete_trip_stats'),
                        style: NordicText.labelMd.copyWith(
                          color: NordicColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Trip Completed',
                  key: const Key('complete_title'),
                  style: NordicText.headlineMd.copyWith(
                    color: NordicColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 24 * -0.025,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        ride.pickup.title,
                        overflow: TextOverflow.ellipsis,
                        style: NordicText.labelLg.copyWith(
                          color: NordicColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const MIcon(
                      Symbols.arrow_forward,
                      size: 16,
                      color: NordicColors.outline,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        ride.dropoff.title,
                        overflow: TextOverflow.ellipsis,
                        style: NordicText.labelLg.copyWith(
                          color: NordicColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                StitchCard(
                  child: Column(
                    children: [
                      if (ride.driver != null) ...[
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            const PhotoCircle(
                              DemoPhotos.driverReceipt,
                              size: 80,
                              ring: NordicColors.surfaceContainer,
                              ringWidth: 4,
                              shadows: Tw.sm,
                              semanticLabel: 'Driver photo',
                            ),
                            Positioned(
                              bottom: -6,
                              child: Elevated(
                                shadows: Tw.sm,
                                radius: 9999,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: NordicColors.primary,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const MIcon(
                                        Symbols.star,
                                        size: 12,
                                        lh: 14,
                                        color: Color(0xFFFBBF24),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DemoDriverProfile.receiptRating,
                                        style: NordicText.labelSm.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          driverName,
                          key: const Key('driver_name'),
                          style: NordicText.titleSm.copyWith(
                            color: NordicColors.primary,
                          ),
                        ),
                        Text(
                          vehicle == null
                              ? 'Nordic Ride driver'
                              : [
                                  if (vehicle.displayName.isNotEmpty)
                                    vehicle.displayName,
                                  if (vehicle.colour != null &&
                                      vehicle.colour!.isNotEmpty)
                                    vehicle.colour!,
                                ].join(' · '),
                          style: NordicText.labelMd.copyWith(
                            color: NordicColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      StitchStars(
                        key: const Key('rating_stars'),
                        value: _rating,
                        onChanged: _submitted
                            ? null
                            : (v) => setState(() => _rating = v),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ratingHeadline(_rating).toUpperCase(),
                        key: const Key('rating_headline'),
                        style: NordicText.labelMd.copyWith(
                          color: NordicColors.secondary,
                          letterSpacing: 12 * 0.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in kRatingTags)
                            _TagPill(
                              key: Key('tag_$t'),
                              label: t,
                              selected: _tags.contains(t),
                              onTap: _submitted
                                  ? null
                                  : () => setState(
                                      () => _tags.contains(t)
                                          ? _tags.remove(t)
                                          : _tags.add(t),
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: NordicColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: MIcon(
                                Symbols.chat_bubble,
                                size: 18,
                                color: NordicColors.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: const Key('rating_comment'),
                                controller: _comment,
                                enabled: !_submitted,
                                minLines: 2,
                                maxLines: 3,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(300),
                                ],
                                style: NordicText.bodySm.copyWith(
                                  color: NordicColors.primary,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  filled: false,
                                  hintText: 'Add a note for $driverName',
                                  hintStyle: NordicText.bodySm.copyWith(
                                    color: NordicColors.outline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Verified review',
                          key: const Key('rating_device_only'),
                          style: NordicText.labelSm.copyWith(
                            color: NordicColors.outline,
                          ),
                        ),
                      ),
                      if (_submitted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Thank you for reviewing your trip.',
                            key: const Key('rating_saved_note'),
                            style: NordicText.labelSm.copyWith(
                              color: NordicColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StitchCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Tip for $driverName',
                            style: NordicText.titleSm.copyWith(
                              color: NordicColors.primary,
                            ),
                          ),
                          Text(
                            'Driver tip',
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TipSelector(
                        labels: [
                          for (final m in kTipPresetsMinor)
                            m == 0 ? 'No tip' : '+${Money.format(m, currency)}',
                          'Custom',
                        ],
                        selected: tipIndex,
                        keys: [
                          for (final m in kTipPresetsMinor) Key('tip_$m'),
                          const Key('tip_custom'),
                        ],
                        onTap: _receipt != null
                            ? null
                            : (i) => i < kTipPresetsMinor.length
                                  ? setState(
                                      () => _tipMinor = kTipPresetsMinor[i],
                                    )
                                  : _customTip(currency),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StitchCard(
                  key: const Key('fare_breakdown'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PAYMENT SUMMARY',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.outline,
                                    letterSpacing: 10 * 0.05,
                                  ),
                                ),
                                Text(
                                  'Trip Receipt',
                                  style: NordicText.titleSm.copyWith(
                                    color: NordicColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: NordicColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const MIcon(
                                    Symbols.receipt_long,
                                    size: 14,
                                    lh: 20,
                                    color: NordicColors.secondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '#${ride.id}',
                                    style: NordicText.labelMd.copyWith(
                                      color: NordicColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (b != null) ...[
                        const SizedBox(height: 4),
                        FareRow(
                          label: 'Base fare',
                          value: Money.format(b.baseFareMinor, currency),
                        ),
                        const SizedBox(height: 8),
                        FareRow(
                          label: 'Distance',
                          suffix: '(${Fmt.distance(b.distanceMeters)})',
                          value: Money.format(b.distanceChargeMinor, currency),
                        ),
                        const SizedBox(height: 8),
                        FareRow(
                          label: 'Time',
                          suffix: '(${Fmt.duration(b.durationSeconds)})',
                          value: Money.format(b.timeChargeMinor, currency),
                        ),
                        if (b.minimumFareAdjustmentMinor > 0) ...[
                          const SizedBox(height: 8),
                          FareRow(
                            label: 'Minimum fare adjustment',
                            value: Money.format(
                              b.minimumFareAdjustmentMinor,
                              currency,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        FareRow(
                          label: 'Booking fee',
                          value: Money.format(b.bookingFeeMinor, currency),
                        ),
                        const SizedBox(height: 8),
                        FareRow(
                          label: 'VAT / tax',
                          value: Money.format(b.taxMinor, currency),
                        ),
                      ],
                      if (_tipMinor > 0) ...[
                        const SizedBox(height: 8),
                        FareRow(
                          label: 'Driver tip',
                          value: Money.format(_tipMinor, currency),
                        ),
                      ],
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        height: 1,
                        color: NordicColors.surfaceContainer,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total fare',
                                style: NordicText.titleMd.copyWith(
                                  color: NordicColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Includes taxes and fees',
                                style: NordicText.labelSm.copyWith(
                                  color: NordicColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            Money.format(total, currency),
                            key: const Key('fare_total'),
                            style: NordicText.currencyDisplay.copyWith(
                              color: NordicColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: NordicColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: NordicColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: MIcon(
                                        method == PaymentMethodType.cash
                                            ? Symbols.payments
                                            : Symbols.credit_card,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          method.label,
                                          style: NordicText.labelLg.copyWith(
                                            color: NordicColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Payment completed',
                                          key: const Key('payment_status_note'),
                                          style: NordicText.labelSm.copyWith(
                                            color: NordicColors.secondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_receipt == null)
                        GestureDetector(
                          key: const Key('confirm_payment'),
                          onTap: _paying
                              ? null
                              : () async {
                                  setState(() => _paying = true);
                                  try {
                                    await _confirmPayment(ride);
                                  } finally {
                                    if (mounted) {
                                      setState(() => _paying = false);
                                    }
                                  }
                                },
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: NordicColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _paying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    method == PaymentMethodType.cash
                                        ? 'Confirm cash payment'
                                        : 'Confirm card payment',
                                    style: NordicText.labelLg.copyWith(
                                      color: NordicColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        )
                      else
                        Container(
                          key: const Key('payment_confirmed'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NordicColors.secondaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const MIcon(
                                Symbols.check_circle,
                                size: 18,
                                color: NordicColors.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Payment confirmed. Reference ${_receipt!.reference}.',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  child: Column(
                    children: [
                      StitchButton(
                        key: const Key('complete_done'),
                        label: _rating > 0 && !_submitted
                            ? 'Done & Submit Review'
                            : 'Done',
                        icon: Symbols.check_circle,
                        background: NordicColors.primaryContainer,
                        radius: 8,
                        loading: _busy,
                        onPressed: () => _done(ride),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LinkAction(
                            key: const Key('report_problem'),
                            icon: Symbols.help,
                            label: 'Report a problem',
                            onTap: () => showReportProblemSheet(
                              context,
                              rideId: ride.id,
                            ),
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: const BoxDecoration(
                              color: NordicColors.outlineVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          _LinkAction(
                            key: const Key('lost_item'),
                            icon: Symbols.luggage,
                            label: 'Lost an item?',
                            onTap: () => showReportProblemSheet(
                              context,
                              rideId: ride.id,
                              initialCategory: 'Lost item',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          MIcon(icon, size: 16, color: NordicColors.outline),
          const SizedBox(width: 4),
          Text(
            label,
            style: NordicText.labelMd.copyWith(
              color: NordicColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

/// `rounded-full` compliment pill: icon + label (display chips in the design, selectable here).
class _TagPill extends StatelessWidget {
  const _TagPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const _icons = {
    'Punctual arrival': Symbols.verified,
    'Smooth driving': Symbols.airline_seat_recline_extra,
    'Clean cabin': Symbols.air,
    'Quiet ride': Symbols.volume_off,
    'Great conversation': Symbols.forum,
  };

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? NordicColors.primaryContainer
            : NordicColors.surfaceContainer,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MIcon(
            _icons[label] ?? Symbols.star,
            size: 12,
            lh: 14,
            color: selected
                ? NordicColors.secondaryFixed
                : NordicColors.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: NordicText.labelSm.copyWith(
              color: selected ? Colors.white : NordicColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
