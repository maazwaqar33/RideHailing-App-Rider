import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../mock/demo_content.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';
import '../application/trip_providers.dart';
import '../domain/trip_models.dart';
import 'trip_widgets.dart';

/// Rating screen (Stitch `rate_and_tip_driver`): stars, compliment tags, personal note and a
/// tip selector. Everything is stored on the device only (no rating / tip endpoint exists) and the
/// tip is part of the MOCK payment receipt: nothing is charged.
class RateTipScreen extends ConsumerStatefulWidget {
  const RateTipScreen({super.key, required this.rideId});

  final int rideId;

  @override
  ConsumerState<RateTipScreen> createState() => _RateTipScreenState();
}

class _RateTipScreenState extends ConsumerState<RateTipScreen> {
  int _rating = 0;
  final _tags = <String>{};
  final _comment = TextEditingController();
  int _tipMinor = 0;
  bool _busy = false;
  bool _submitted = false;
  PaymentReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final receipt = await ref
        .read(paymentServiceProvider)
        .receiptFor(widget.rideId);
    final feedback = await ref
        .read(feedbackRepositoryProvider)
        .get(widget.rideId);
    if (!mounted) return;
    setState(() {
      _receipt = receipt;
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

  Future<void> _submit(Ride ride) async {
    if (_busy || _rating == 0) return;
    setState(() => _busy = true);
    try {
      _receipt ??= await ref
          .read(paymentServiceProvider)
          .confirm(
            ride: ride,
            method: PaymentMethodType.parse(ride.payment.method),
            tipMinor: _tipMinor,
          );
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
      ref.invalidate(mockReceiptProvider(ride.id));
      if (!mounted) return;
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thank you for your review!',
          ),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(rideDetailProvider(widget.rideId));
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Column(
        children: [
          StitchBackHeader(
            title: 'Rating',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
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
    final driverName = ride.driver?.firstName ?? 'your driver';
    final vehicle = ride.vehicle;
    final method = PaymentMethodType.parse(ride.payment.method);
    final presetIndex = kTipPresetsMinor.indexOf(_tipMinor);
    final tipIndex = presetIndex >= 0 ? presetIndex : kTipPresetsMinor.length;
    final locked = _submitted;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          StitchCard(
            backdrop: const Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  top: -48,
                  right: -48,
                  child: Blob(size: 160, color: Color(0x3371F8E4), blur: 40),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: NordicColors.secondaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: NordicColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Trip completed',
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (vehicle != null)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            [
                              if (vehicle.displayName.isNotEmpty)
                                vehicle.displayName,
                              vehicle.plateNumber,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${ride.pickup.title} → ${ride.dropoff.title}',
                  key: const Key('rate_route'),
                  style: NordicText.headlineSm.copyWith(
                    color: NordicColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trip with $driverName · ${Fmt.distance(ride.distanceMeters)} · ${Fmt.duration(ride.durationSeconds)}',
                  style: NordicText.bodySm.copyWith(
                    color: NordicColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const PhotoCircle(
                          DemoPhotos.driverRating,
                          size: 96,
                          shadows: Tw.md,
                          semanticLabel: 'Driver photo',
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Elevated(
                            shadows: Tw.sm,
                            circle: true,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: NordicColors.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: const MIcon(
                                Symbols.verified,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        driverName,
                        key: const Key('driver_name'),
                        style: NordicText.titleMd.copyWith(
                          color: NordicColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NordicColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MIcon(
                              Symbols.star,
                              size: 14,
                              lh: 16,
                              color: NordicColors.tertiaryFixedDim,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              DemoDriverProfile.rating,
                              style: NordicText.labelMd.copyWith(
                                color: NordicColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    DemoDriverProfile.subtitle,
                    style: NordicText.bodySm.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: StitchStars(
                    key: const Key('rating_stars'),
                    value: _rating,
                    size: 36,
                    minTarget: 44,
                    activeColor: NordicColors.tertiaryFixedDim,
                    onChanged: locked
                        ? null
                        : (v) => setState(() => _rating = v),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    ratingHeadline(_rating).toUpperCase(),
                    key: const Key('rating_headline'),
                    style: NordicText.labelMd.copyWith(
                      color: NordicColors.secondary,
                      letterSpacing: 12 * 0.025,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'What made the ride special?',
                  style: NordicText.labelMd.copyWith(
                    color: NordicColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in kRatingTags)
                      GestureDetector(
                        key: Key('tag_$t'),
                        onTap: locked
                            ? null
                            : () => setState(
                                () => _tags.contains(t)
                                    ? _tags.remove(t)
                                    : _tags.add(t),
                              ),
                        child: Elevated(
                          shadows: _tags.contains(t) ? Tw.sm : const [],
                          radius: 9999,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _tags.contains(t)
                                  ? NordicColors.primary
                                  : NordicColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              t,
                              style: NordicText.labelMd.copyWith(
                                color: _tags.contains(t)
                                    ? Colors.white
                                    : NordicColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Personal note for $driverName',
                  style: NordicText.labelMd.copyWith(
                    color: NordicColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('rating_comment'),
                        controller: _comment,
                        enabled: !locked,
                        minLines: 3,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(300),
                        ],
                        style: NordicText.bodySm.copyWith(
                          color: NordicColors.onSurface,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          hintText: 'Share your experience...',
                          hintStyle: NordicText.bodySm.copyWith(
                            color: NordicColors.outline,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${_comment.text.length}/300',
                            style: NordicText.labelSm.copyWith(
                              color: NordicColors.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Your review is saved on this device. The backend has no ratings endpoint, so it will not appear in Admin.',
                      key: const Key('rating_saved_note'),
                      style: NordicText.labelSm.copyWith(
                        color: NordicColors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          StitchCard(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add a tip for $driverName',
                            style: NordicText.titleSm.copyWith(
                              color: NordicColors.onSurface,
                            ),
                          ),
                          Text(
                            '100% of tips go to your driver',
                            style: NordicText.bodySm.copyWith(
                              color: NordicColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: NordicColors.secondaryFixed.withValues(
                          alpha: 0.4,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: MIcon(
                          Symbols.volunteer_activism,
                          size: 20,
                          color: NordicColors.onSecondaryFixedVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TipSelector(
                  height: 56,
                  labels: [
                    for (final m in kTipPresetsMinor)
                      m == 0 ? 'No tip' : '+${Money.format(m, currency)}',
                    'Custom',
                  ],
                  sublabels: {
                    if (kTipPresetsMinor.contains(500))
                      kTipPresetsMinor.indexOf(500): 'Popular',
                  },
                  keys: [
                    for (final m in kTipPresetsMinor) Key('tip_$m'),
                    const Key('tip_custom'),
                  ],
                  selected: tipIndex,
                  selectedBackground: NordicColors.secondary,
                  unselectedBackground: NordicColors.surfaceContainer,
                  unselectedForeground: NordicColors.onSurface,
                  onTap: (_receipt != null || locked)
                      ? null
                      : (i) => i < kTipPresetsMinor.length
                            ? setState(() => _tipMinor = kTipPresetsMinor[i])
                            : _customTip(currency),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: NordicColors.onTertiaryContainer.withValues(
                            alpha: 0.1,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: MIcon(
                            Symbols.account_balance_wallet,
                            size: 16,
                            color: NordicColors.onTertiaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              method.label,
                              style: NordicText.labelMd.copyWith(
                                color: NordicColors.onSurface,
                              ),
                            ),
                            Text(
                              'Default payment method',
                              key: const Key('payment_status_note'),
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.onSurfaceVariant,
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
          const SizedBox(height: 24),
          StitchButton(
            key: const Key('submit_review'),
            label: locked ? 'Review saved' : 'Submit Review',
            icon: locked ? Symbols.check : Symbols.arrow_forward,
            background: NordicColors.primaryContainer,
            radius: 12,
            loading: _busy,
            onPressed: (locked || _rating == 0) ? null : () => _submit(ride),
          ),
          const SizedBox(height: 8),
          Text(
            _rating == 0 && !locked
                ? 'Tap a star to rate your driver'
                : 'Thank you for your feedback',
            textAlign: TextAlign.center,
            style: NordicText.labelSm.copyWith(color: NordicColors.outline),
          ),
        ],
      ),
    );
  }
}
