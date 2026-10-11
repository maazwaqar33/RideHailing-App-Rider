import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/network/api_exception.dart';
import '../../rides/application/ride_providers.dart';
import '../../rides/domain/ride_models.dart';

/// Result of the cancel sheet.
class CancelOutcome {
  const CancelOutcome({this.ride, this.error});

  /// Updated ride (status cancelled) returned by POST rides/{id}/cancel.
  final Ride? ride;
  final ApiException? error;
}

/// Bottom sheet: pick a reason, confirm, call POST rides/{id}/cancel.
/// The confirm button shows a spinner and ignores taps while the request is in flight.
Future<CancelOutcome?> showCancelRideSheet(
  BuildContext context, {
  required Ride ride,
}) {
  return showNordicBottomSheet<CancelOutcome>(
    context: context,
    title: 'Cancel this ride?',
    builder: (_) => CancelRideForm(ride: ride),
  );
}

class CancelRideForm extends ConsumerStatefulWidget {
  const CancelRideForm({super.key, required this.ride});

  final Ride ride;

  @override
  ConsumerState<CancelRideForm> createState() => _CancelRideFormState();
}

class _CancelRideFormState extends ConsumerState<CancelRideForm> {
  String? _reason;
  final _other = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String? get _finalReason {
    if (_reason == null) return null;
    if (_reason == 'Other') {
      final t = _other.text.trim();
      return t.length >= 3 ? t : null; // API requires 3-500 characters
    }
    return _reason;
  }

  Future<void> _confirm() async {
    final reason = _finalReason;
    if (_busy || reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(rideRepositoryProvider)
          .cancel(widget.ride.id, reason);
      ref.invalidate(activeRideProvider);
      if (mounted) Navigator.of(context).pop(CancelOutcome(ride: updated));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        // The ride moved on (e.g. the trip already started): let the caller refresh.
        Navigator.of(context).pop(CancelOutcome(error: e));
        return;
      }
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final freeText = _reason == 'Other';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tell us why (required).',
            style: NordicText.bodyMd.copyWith(
              color: NordicColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in kCancelReasons)
                NordicChip(
                  key: Key('reason_$r'),
                  label: r,
                  selected: _reason == r,
                  onTap: _busy ? null : () => setState(() => _reason = r),
                ),
            ],
          ),
          if (freeText) ...[
            const SizedBox(height: 12),
            NordicTextField(
              key: const Key('reason_other_field'),
              label: 'Reason',
              controller: _other,
              hint: 'At least 3 characters',
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            NordicBanner(
              key: const Key('cancel_error'),
              message: _error!,
              tone: NordicTone.critical,
            ),
          ],
          const SizedBox(height: 16),
          NordicButton(
            key: const Key('confirm_cancel'),
            label: 'Cancel ride',
            variant: NordicButtonVariant.destructive,
            isLoading: _busy,
            onPressed: _finalReason == null ? null : _confirm,
          ),
          const SizedBox(height: 8),
          NordicButton(
            key: const Key('keep_ride'),
            label: 'Keep my ride',
            variant: NordicButtonVariant.tertiary,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
