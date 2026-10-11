import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../../auth/application/session_controller.dart';
import '../../rides/domain/ride_models.dart';
import '../application/tracking_controller.dart';
import '../domain/driver_telemetry.dart';
import '../domain/ride_status_machine.dart';
import 'cancel_ride_sheet.dart';
import 'stage_arrived.dart';
import 'stage_driver_found.dart';
import 'stage_live.dart';
import 'stage_searching.dart';

/// Live ride screen. Status comes from REAL polling of GET rides/{id} (no websocket exists).
/// The driver position on the map is a MOCK simulation and is labelled as such.
///
/// Stitch layouts: searching_for_driver (requested/offered), driver_found_erik_larsen (accepted),
/// live_tracking_3_states (driver_en_route, in_progress) and live_trip_driver_arrived_pin_4821 (arrived).
/// The design's rating, trip counter, security PIN, chat, share and SOS have no backend: they are
/// omitted (not built).
class RideScreen extends ConsumerStatefulWidget {
  const RideScreen({super.key, required this.rideId});

  final int rideId;

  @override
  ConsumerState<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends ConsumerState<RideScreen> {
  Timer? _clock;
  bool _arrivalBanner = false;

  /// Ticked once a second. Only small widgets (the elapsed label, the map section) listen to
  /// these; the screen itself is NOT rebuilt by the clock.
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  final ValueNotifier<DriverPosition?> _positions = ValueNotifier(null);

  void _tick() {
    if (!mounted) return;
    _now.value = DateTime.now();
    _updatePositions();
  }

  /// Recomputes the (mock) driver position for the current ride; a no-op when nothing changed
  /// (`DriverPosition` is Equatable, so the notifier does not fire for identical values).
  void _updatePositions() {
    final ride = ref.read(rideTrackingProvider(widget.rideId)).ride;
    final stage = ride == null ? null : RideStatusMachine.stageOf(ride.status);
    final driverStage =
        stage == TrackingStage.driverAssigned ||
        stage == TrackingStage.driverOnTheWay ||
        stage == TrackingStage.inTrip ||
        stage == TrackingStage.driverArrived;
    _positions.value = (ride != null && driverStage)
        ? ref.read(driverTelemetryProvider).positionAt(ride, DateTime.now())
        : null;
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePositions());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _now.dispose();
    _positions.dispose();
    super.dispose();
  }

  void _onTracking(RideTrackingState? prev, RideTrackingState next) {
    if (next.ride != prev?.ride) {
      // Ride changed (status poll): refresh the mock position immediately (after this frame).
      WidgetsBinding.instance.addPostFrameCallback((_) => _updatePositions());
    }
    if (next.events != prev?.events) {
      for (final e in next.events) {
        if (e.type == RideEventType.driverArrived) {
          // In-app alert + haptic (no push / local-notification plugin is used).
          HapticFeedback.heavyImpact();
          setState(() => _arrivalBanner = true);
        }
      }
    }
    final status = next.ride?.status;
    if (status == RideStatus.completed &&
        prev?.ride?.status != RideStatus.completed) {
      context.pushReplacement('/ride-complete/${widget.rideId}');
    }
  }

  Future<void> _cancel(Ride ride) async {
    final outcome = await showCancelRideSheet(context, ride: ride);
    if (outcome == null || !mounted) return;
    final controller = ref.read(rideTrackingProvider(widget.rideId).notifier);
    if (outcome.ride != null) {
      controller.applyRide(outcome.ride!);
    } else {
      // 409: the ride advanced under us. Re-sync and tell the rider.
      await controller.poll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome.error?.message ?? 'The ride can no longer be cancelled.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rideTrackingProvider(widget.rideId), _onTracking);
    // Rebuild only when something the UI shows changed: identical polls (new `lastSyncedAt`,
    // same ride) do not rebuild the screen or the map.
    final state = ref.watch(
      rideTrackingProvider(widget.rideId)
          .select((s) => (ride: s.ride, error: s.error)),
    );
    final session = ref.watch(sessionControllerProvider);
    final userName = session is SessionAuthenticated ? session.user.name : '';
    final ride = state.ride;
    final pad = MediaQuery.paddingOf(context);
    // live_tracking_3_states uses a plain 'Tracking' header; the other stages use the logo header.
    final plainHeader =
        ride != null &&
        (ride.status == RideStatus.driverEnRoute ||
            ride.status == RideStatus.inProgress);

    Widget body;
    if (ride == null) {
      body = state.error != null
          ? NordicErrorView(
              message: state.error!.message,
              onRetry: () =>
                  ref.read(rideTrackingProvider(widget.rideId).notifier).poll(),
            )
          : const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  NordicSkeletonRow(),
                  NordicSkeletonRow(),
                  NordicSkeletonRow(),
                ],
              ),
            );
    } else {
      switch (RideStatusMachine.stageOf(ride.status)) {
        case TrackingStage.searching:
          body = SearchingView(
            ride: ride,
            now: _now,
            onCancel: () => _cancel(ride),
          );
        case TrackingStage.cancelled:
          body = _CancelledView(ride: ride);
        case TrackingStage.completed:
          body = const NordicLoader(message: 'Trip completed...');
        case TrackingStage.driverAssigned:
          body = DriverFoundView(
            ride: ride,
            positions: _positions,
            onCancel: () => _cancel(ride),
          );
        case TrackingStage.driverOnTheWay:
        case TrackingStage.inTrip:
          body = LiveTrackingView(
            ride: ride,
            positions: _positions,
            onCancel: () => _cancel(ride),
          );
        case TrackingStage.driverArrived:
          body = DriverArrivedView(
            ride: ride,
            positions: _positions,
            onCancel: () => _cancel(ride),
          );
      }
    }

    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child:
                ride != null &&
                    RideStatusMachine.stageOf(ride.status) ==
                        TrackingStage.cancelled
                ? Padding(
                    padding: EdgeInsets.only(top: kHeaderHeight + pad.top),
                    child: body,
                  )
                : (ride == null ||
                      RideStatusMachine.stageOf(ride.status) ==
                          TrackingStage.completed)
                ? Padding(
                    padding: EdgeInsets.only(top: kHeaderHeight + pad.top),
                    child: body,
                  )
                : body,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StitchBackHeader(
              title: plainHeader ? 'Tracking' : 'Live Trip Tracking',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              showLogo: !plainHeader,
              iosBack: !plainHeader,
              userName: plainHeader ? null : userName,
            ),
          ),
          if (state.error != null && ride != null)
            Positioned(
              top: kHeaderHeight + pad.top + 8,
              left: 16,
              child: Tooltip(
                message: 'Reconnecting: ${state.error!.message}',
                child: const MIcon(
                  Symbols.sync_problem,
                  size: 22,
                  color: NordicColors.onTertiaryContainer,
                  key: Key('reconnecting_icon'),
                ),
              ),
            ),
          if (_arrivalBanner)
            Positioned(
              top: kHeaderHeight + pad.top + 8,
              left: 16,
              right: 16,
              child: Dismissible(
                key: const Key('arrival_banner'),
                onDismissed: (_) => setState(() => _arrivalBanner = false),
                child: NordicBanner(
                  tone: NordicTone.success,
                  title: 'Your driver has arrived',
                  message: 'Look for the vehicle at your pickup point.',
                  icon: Icons.notifications_active_outlined,
                  actionLabel: 'Dismiss',
                  onAction: () => setState(() => _arrivalBanner = false),
                ),
              ),
            ),
          if (ride != null && !ride.status.isTerminal)
            Positioned(
              right: 16,
              bottom: pad.bottom + 16,
              child: FloatingActionButton.small(
                key: const Key('demo_skip_stage'),
                heroTag: 'demo_skip_stage',
                backgroundColor: NordicColors.primary,
                foregroundColor: Colors.white,
                tooltip: 'Fast forward',
                onPressed: () => ref
                    .read(rideTrackingProvider(widget.rideId).notifier)
                    .advanceDemoStage(),
                child: const Icon(Icons.fast_forward, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _CancelledView extends StatelessWidget {
  const _CancelledView({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: NordicColors.criticalSurface,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: MIcon(
                  Symbols.close,
                  size: 36,
                  color: NordicColors.error,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ride cancelled',
              key: const Key('cancelled_title'),
              style: NordicText.headlineMd.copyWith(
                color: NordicColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            if (ride.cancellationReason != null)
              Text(
                'Reason: ${ride.cancellationReason}',
                style: NordicText.bodyMd.copyWith(
                  color: NordicColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 4),
            Text(
              'No charge was made.',
              style: NordicText.bodyMd.copyWith(
                color: NordicColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            StitchButton(
              key: const Key('cancelled_home'),
              label: 'Back to home',
              onPressed: () => context.go('/home'),
              radius: 12,
            ),
          ],
        ),
      ),
    );
  }
}
