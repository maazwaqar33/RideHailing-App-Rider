import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/geo/geo.dart';
import '../../../shared/app_map.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../application/map_providers.dart';
import '../domain/map_models.dart';

enum PickTarget { pickup, dropoff }

/// Stitch `confirm_pickup`: drag the map under a fixed pin. The label is the nearest known demo
/// place (within 150 m) or the raw coordinates (there is no reverse-geocoding service).
/// The optional driver note is appended to the pickup address when the ride is requested.
class PickOnMapScreen extends ConsumerStatefulWidget {
  const PickOnMapScreen({super.key, required this.target});

  final PickTarget target;

  @override
  ConsumerState<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends ConsumerState<PickOnMapScreen> {
  static const double _mapHeight = 380;
  final _controller = MapController();
  final _note = TextEditingController();
  late LatLng _centre;
  Place? _label;
  bool _noteOpen = false;

  bool get _isPickup => widget.target == PickTarget.pickup;

  @override
  void initState() {
    super.initState();
    final plan = ref.read(tripPlanProvider);
    final existing = _isPickup ? plan.pickup : plan.dropoff;
    _centre = existing?.position ?? plan.pickup?.position ?? kOsloCentre;
    _note.text = plan.pickupNote;
    _noteOpen = plan.pickupNote.isNotEmpty;
    _resolveLabel();
  }

  @override
  void dispose() {
    _controller.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _resolveLabel() async {
    final centre = _centre;
    final known = await ref
        .read(placeSearchRepositoryProvider)
        .nearestKnownPlace(centre);
    if (!mounted || centre != _centre) return;
    setState(() => _label = known);
  }

  Place get _selected =>
      _label ??
      Place.pin(_centre, name: _isPickup ? 'Pickup pin' : 'Dropped pin');

  void _confirm() {
    final notifier = ref.read(tripPlanProvider.notifier);
    if (_isPickup) {
      notifier.setPickup(_selected);
      notifier.setPickupNote(_note.text);
    } else {
      notifier.setDropoff(_selected);
    }
    context.pop();
  }

  static String _badge(Place p) => switch (p.kind) {
    PlaceKind.transit => 'Central hub',
    PlaceKind.airport => 'Airport',
    PlaceKind.museum || PlaceKind.landmark => 'Landmark',
    PlaceKind.business => 'Business',
    _ => 'Map pin',
  };

  static IconData _badgeIcon(Place p) => switch (p.kind) {
    PlaceKind.transit => Symbols.train,
    PlaceKind.airport => Symbols.flight,
    PlaceKind.museum || PlaceKind.landmark => Symbols.account_balance,
    PlaceKind.business => Symbols.business_center,
    _ => Symbols.push_pin,
  };

  @override
  Widget build(BuildContext context) {
    final place = _selected;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: kHeaderHeight + pad.top),
              child: Stack(
                children: [
                  SizedBox(
                    height: _mapHeight,
                    width: double.infinity,
                    child: ColoredBox(
                      color: NordicColors.surfaceContainerHigh,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          // The map is 40 px taller at the top so its centre sits under the pin (pb-10 in the design).
                          Positioned(
                            top: -40,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: AppMap(
                              center: _centre,
                              zoom: 15,
                              controller: _controller,
                              onPositionChanged: (camera, hasGesture) {
                                if (!hasGesture) return;
                                _centre = camera.center;
                                _resolveLabel();
                                setState(() {});
                              },
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Tw.a(NordicColors.primary, 0.1),
                                      Tw.a(NordicColors.primary, 0),
                                      Tw.a(NordicColors.primary, 0.25),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Column(
                              children: [
                                _MapButton(
                                  icon: Symbols.my_location,
                                  size: 22,
                                  color: NordicColors.primary,
                                  onTap: () => _controller.move(_centre, 15),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Elevated(
                              shadows: Tw.sm,
                              radius: 9999,
                              child: BackdropBlur(
                                radius: 9999,
                                blur: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  color: Tw.a(
                                    NordicColors.surfaceContainerLowest,
                                    0.9,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const MIcon(
                                        Symbols.eco,
                                        size: 16,
                                        color: NordicColors.secondary,
                                        lh: 24,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Oslo area',
                                        style: NordicText.labelMd.copyWith(
                                          color: NordicColors.onSurface,
                                          letterSpacing: 12 * -0.025,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Centered pickup pin & target system (the dot is the selected point).
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 40),
                                child: Center(
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          color: Tw.a(
                                            NordicColors.secondaryContainer,
                                            0.3,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Tw.a(
                                            NordicColors.secondaryFixed,
                                            0.4,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Elevated(
                                        shadows: Tw.sm,
                                        circle: true,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: const BoxDecoration(
                                            color: NordicColors.secondary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        // Stack is the 96 px halo: top is relative to its top edge (= centre - 48).
                                        top: -44,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Elevated(
                                              shadows: Tw.xl,
                                              radius: 9999,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: NordicColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        9999,
                                                      ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: NordicColors
                                                                .secondaryFixedDim,
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _isPickup
                                                          ? 'Set pickup here · Drag map to adjust'
                                                          : 'Set destination here · Drag map to adjust',
                                                      style: NordicText.labelMd
                                                          .copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Transform.translate(
                                              offset: const Offset(0, -4),
                                              child: Transform.rotate(
                                                angle: 0.785398,
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  color: NordicColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: -4,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Elevated(
                                              shadows: Tw.xl,
                                              circle: true,
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: NordicColors.primary,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    Tw.ring(
                                                      NordicColors
                                                          .secondaryFixed,
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: MIcon(
                                                    _isPickup
                                                        ? Symbols.local_taxi
                                                        : Symbols.flag,
                                                    size: 22,
                                                    fill: 1,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Transform.translate(
                                              offset: const Offset(0, -2),
                                              child: Container(
                                                width: 6,
                                                height: 12,
                                                decoration: const BoxDecoration(
                                                  color: NordicColors.primary,
                                                  borderRadius:
                                                      BorderRadius.vertical(
                                                        bottom: Radius.circular(
                                                          9999,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom sheet
                  Column(
                    children: [
                      const SizedBox(height: _mapHeight - 24),
                      Elevated(
                        shadows: Tw.xl2,
                        radius: 24,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          decoration: const BoxDecoration(
                            color: NordicColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Tw.a(
                                      NordicColors.outlineVariant,
                                      0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            NordicColors.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          MIcon(
                                            _badgeIcon(place),
                                            size: 16,
                                            color: NordicColors.secondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _badge(place).toUpperCase(),
                                            style: NordicText.labelMd.copyWith(
                                              color: NordicColors.onSurface,
                                              letterSpacing: 12 * 0.05,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const MIcon(
                                          Symbols.bolt,
                                          size: 16,
                                          color: NordicColors.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _label == null
                                              ? 'Map pin'
                                              : 'Selected place',
                                          style: NordicText.labelMd.copyWith(
                                            color: NordicColors.secondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: NordicColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: NordicColors.primaryFixed,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: MIcon(
                                          Symbols.location_on,
                                          size: 20,
                                          fill: 1,
                                          color: NordicColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            place.name,
                                            key: const Key('pin_label'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: NordicText.titleSm.copyWith(
                                              color: NordicColors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            place.address,
                                            style: NordicText.bodySm.copyWith(
                                              color:
                                                  NordicColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isPickup)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        key: const Key('note_toggle'),
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => setState(
                                          () => _noteOpen = !_noteOpen,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: NordicColors
                                                .surfaceContainerLowest,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const MIcon(
                                                    Symbols.edit_note,
                                                    size: 20,
                                                    color: NordicColors
                                                        .onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    _note.text.isEmpty
                                                        ? 'Add pickup note for driver'
                                                        : 'Pickup note added',
                                                    style: NordicText.labelLg
                                                        .copyWith(
                                                          color: NordicColors
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              AnimatedRotation(
                                                turns: _noteOpen ? 0.25 : 0,
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                child: const MIcon(
                                                  Symbols.chevron_right,
                                                  size: 18,
                                                  color: NordicColors.outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (_noteOpen)
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: NordicColors
                                                .surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'NOTE DETAILS',
                                                style: NordicText.labelSm
                                                    .copyWith(
                                                      color:
                                                          NordicColors.outline,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: NordicColors
                                                      .surfaceContainerLowest,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: TextField(
                                                  key: const Key(
                                                    'pickup_note_field',
                                                  ),
                                                  controller: _note,
                                                  maxLength: 120,
                                                  onChanged: (_) =>
                                                      setState(() {}),
                                                  style: NordicText.bodySm
                                                      .copyWith(
                                                        color: NordicColors
                                                            .onSurface,
                                                      ),
                                                  decoration: InputDecoration(
                                                    isCollapsed: true,
                                                    border: InputBorder.none,
                                                    counterText: '',
                                                    hintText: 'e.g. Waiting beside the sculpture...',
                                                    hintStyle: NordicText.bodySm
                                                        .copyWith(
                                                          color: NordicColors
                                                              .outline,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox(height: 4),
                              StitchButton(
                                key: const Key('pin_confirm'),
                                label: _isPickup
                                    ? 'Confirm pickup'
                                    : 'Confirm destination',
                                icon: Symbols.arrow_forward,
                                onPressed: _confirm,
                                background: NordicColors.primaryContainer,
                                radius: 8,
                                shadow: Tw.lg,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StitchBackHeader(
              title: _isPickup ? 'Confirm Pickup' : 'Confirm Destination',
              onBack: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Elevated(
      shadows: Tw.md,
      circle: true,
      child: BackdropBlur(
        radius: 22,
        blur: 12,
        child: Container(
          width: 44,
          height: 44,
          color: Tw.a(NordicColors.surfaceContainerLowest, 0.95),
          child: Center(
            child: MIcon(icon, size: size, color: color),
          ),
        ),
      ),
    ),
  );
}
