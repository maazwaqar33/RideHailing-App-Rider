import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/geo/geo.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../application/map_providers.dart';
import '../data/local_places_store.dart';
import '../domain/map_models.dart';

enum _Field { pickup, dropoff }

/// Stitch `search_destination`. Pickup/destination search over the MOCK Oslo place dataset
/// (distances are straight-line estimates). With `?set=home|work` it picks a place to save instead.
class SearchDestinationScreen extends ConsumerStatefulWidget {
  const SearchDestinationScreen({super.key, this.setSlot});

  final SavedSlot? setSlot;

  @override
  ConsumerState<SearchDestinationScreen> createState() =>
      _SearchDestinationScreenState();
}

class _SearchDestinationScreenState
    extends ConsumerState<SearchDestinationScreen> {
  late final TextEditingController _pickup;
  late final TextEditingController _dropoff;
  final _pickupFocus = FocusNode();
  final _dropoffFocus = FocusNode();
  _Field _active = _Field.dropoff;
  List<Place> _results = const [];
  String _query = '';

  bool get _settingSaved => widget.setSlot != null;

  @override
  void initState() {
    super.initState();
    final plan = ref.read(tripPlanProvider);
    _pickup = TextEditingController(text: plan.pickup?.name ?? '');
    _dropoff = TextEditingController(
      text: _settingSaved ? '' : (plan.dropoff?.name ?? ''),
    );
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) _setActive(_Field.pickup);
    });
    _dropoffFocus.addListener(() {
      if (_dropoffFocus.hasFocus) _setActive(_Field.dropoff);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_settingSaved) _dropoffFocus.requestFocus();
      _runSearch('');
    });
  }

  void _setActive(_Field f) {
    if (_active != f) {
      setState(() => _active = f);
      _runSearch(f == _Field.pickup ? _pickup.text : _dropoff.text);
    }
  }

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    _pickupFocus.dispose();
    _dropoffFocus.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    _query = q;
    final plan = ref.read(tripPlanProvider);
    final repo = ref.read(placeSearchRepositoryProvider);
    final res = q.trim().isEmpty
        ? await repo.suggestions(near: plan.pickup?.position)
        : await repo.search(q, near: plan.pickup?.position);
    if (!mounted || q != _query) return;
    setState(() => _results = res);
  }

  Future<void> _select(Place place) async {
    if (_settingSaved) {
      await ref.read(localPlacesStoreProvider).setSaved(widget.setSlot!, place);
      if (mounted) context.pop();
      return;
    }
    final notifier = ref.read(tripPlanProvider.notifier);
    if (_active == _Field.pickup) {
      notifier.setPickup(place);
      _pickup.text = place.name;
      _dropoffFocus.requestFocus();
    } else {
      notifier.setDropoff(place);
      _dropoff.text = place.name;
      FocusScope.of(context).unfocus();
    }
    setState(() {});
  }

  Future<void> _pickOnMap() async {
    final target = _active == _Field.pickup ? 'pickup' : 'dropoff';
    await context.push('/pick-on-map?target=$target');
    if (!mounted) return;
    final plan = ref.read(tripPlanProvider);
    _pickup.text = plan.pickup?.name ?? '';
    _dropoff.text = plan.dropoff?.name ?? '';
    setState(() {});
  }

  Future<void> _next() async {
    final plan = ref.read(tripPlanProvider);
    if (plan.dropoff != null) {
      await ref.read(localPlacesStoreProvider).addRecent(plan.dropoff!);
    }
    if (mounted) context.push('/choose-ride');
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(tripPlanProvider);
    final store = ref.watch(localPlacesStoreProvider);
    final home = store.saved(SavedSlot.home);
    final work = store.saved(SavedSlot.work);
    final pickupPos = plan.pickup?.position;
    double? tripMeters;
    if (plan.isComplete) {
      tripMeters = haversineMeters(
        plan.pickup!.position,
        plan.dropoff!.position,
      );
    }
    final tooClose = tripMeters != null && tripMeters < kMinTripMeters;
    final showNext = !_settingSaved && plan.dropoff != null;
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: kHeaderHeight + pad.top,
                bottom: showNext ? 96 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_settingSaved) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Elevated(
                              shadows: Tw.sm,
                              radius: 9999,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: NordicColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: NordicColors.secondaryFixed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Design copy: "Oslo Fjord Dispatch Active"
                                    Flexible(
                                      child: Text(
                                        'OSLO METROPOLITAN AREA',
                                        overflow: TextOverflow.ellipsis,
                                        style: NordicText.labelMd.copyWith(
                                          color: NordicColors.onSurfaceVariant,
                                          letterSpacing: 12 * 0.05,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const MIcon(
                                Symbols.info,
                                size: 16,
                                color: NordicColors.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Oslo Places',
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Elevated(
                        shadows: Tw.md,
                        radius: 12,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: NordicColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _RouteField(
                                key: const Key('pickup_field'),
                                label: 'Pickup Point',
                                controller: _pickup,
                                focusNode: _pickupFocus,
                                active: _active == _Field.pickup,
                                marker: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: NordicColors.secondaryFixed,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      Tw.ring(
                                        Tw.a(
                                          NordicColors.secondaryContainer,
                                          0.4,
                                        ),
                                        4,
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: GestureDetector(
                                  onTap: _pickOnMap,
                                  child: const SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Center(
                                      child: MIcon(
                                        Symbols.my_location,
                                        size: 20,
                                        color: NordicColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                onChanged: _runSearch,
                                hint: 'Where from?',
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 4, 0, 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    children: [
                                      for (var i = 0; i < 3; i++) ...[
                                        if (i > 0) const SizedBox(height: 4),
                                        Container(
                                          width: 2,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: NordicColors.outlineVariant,
                                            borderRadius: BorderRadius.circular(
                                              9999,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              _RouteField(
                                key: const Key('dropoff_field'),
                                label: 'Destination',
                                controller: _dropoff,
                                focusNode: _dropoffFocus,
                                active: _active == _Field.dropoff,
                                marker: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: NordicColors.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                trailing: _dropoff.text.isEmpty
                                    ? null
                                    : GestureDetector(
                                        key: const Key('clear_dropoff'),
                                        onTap: () {
                                          _dropoff.clear();
                                          ref
                                              .read(tripPlanProvider.notifier)
                                              .clearDropoff();
                                          _runSearch('');
                                        },
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: const BoxDecoration(
                                            color:
                                                NordicColors.surfaceContainer,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: MIcon(
                                              Symbols.close,
                                              size: 18,
                                              color:
                                                  NordicColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                onChanged: (v) {
                                  setState(() {});
                                  _runSearch(v);
                                },
                                hint: 'Where to in Oslo?',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Shortcut(
                              icon: Symbols.home,
                              iconBg: NordicColors.surfaceContainerHigh,
                              iconColor: NordicColors.primary,
                              title: 'Home',
                              place: home,
                              onTap: home == null
                                  ? () => context.push('/search?set=home')
                                  : () => _select(home),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Shortcut(
                              icon: Symbols.domain,
                              iconBg: Tw.a(
                                NordicColors.secondaryContainer,
                                0.4,
                              ),
                              iconColor: NordicColors.onSecondaryContainer,
                              title: 'Work',
                              place: work,
                              onTap: work == null
                                  ? () => context.push('/search?set=work')
                                  : () => _select(work),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: GestureDetector(
                        key: const Key('choose_on_map'),
                        onTap: _pickOnMap,
                        child: Elevated(
                          shadows: Tw.md,
                          radius: 12,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: NordicColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Tw.a(
                                            NordicColors.secondaryFixed,
                                            0.2,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: MIcon(
                                            Symbols.explore,
                                            size: 24,
                                            color: NordicColors.secondaryFixed,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Choose on map',
                                              style: NordicText.titleSm
                                                  .copyWith(
                                                    color: Colors.white,
                                                  ),
                                            ),
                                            Text(
                                              'Drop pin anywhere across Greater Oslo',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: NordicText.bodySm.copyWith(
                                                color: NordicColors
                                                    .primaryFixedDim,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: NordicColors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: MIcon(
                                      Symbols.arrow_forward,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: _RouteField(
                        key: const Key('set_saved_field'),
                        label: 'Search a place in Oslo',
                        controller: _dropoff,
                        focusNode: _dropoffFocus,
                        active: true,
                        marker: const MIcon(
                          Symbols.search,
                          size: 20,
                          color: NordicColors.onSurfaceVariant,
                        ),
                        onChanged: _runSearch,
                        hint: 'Search places in Oslo',
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const MIcon(
                              Symbols.history,
                              size: 20,
                              color: NordicColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _query.trim().isEmpty
                                  ? 'Suggested destinations'
                                  : 'Results',
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'STRAIGHT-LINE EST.',
                          style: NordicText.labelMd.copyWith(
                            color: NordicColors.onSurfaceVariant,
                            letterSpacing: 12 * 0.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      children: [
                        if (_results.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No matching places found.',
                              style: NordicText.bodyMd.copyWith(
                                color: NordicColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        for (final (i, p) in _results.indexed) ...[
                          const SizedBox(height: 8),
                          _ResultTile(
                            place: p,
                            first: i == 0,
                            from: _settingSaved ? null : pickupPos,
                            onTap: () => _select(p),
                          ),
                        ],
                      ],
                    ),
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
              title: _settingSaved
                  ? 'Set ${widget.setSlot!.name}'
                  : 'Destination Search',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          if (showNext)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + pad.bottom,
              child: tooClose
                  ? const NordicBanner(
                      key: Key('too_close_banner'),
                      message: 'Pickup and destination are too close together. Choose a destination at least 100 m away.',
                      tone: NordicTone.pending,
                    )
                  : Elevated(
                      shadows: Tw.xl,
                      radius: 16,
                      child: Container(
                        key: const Key('next_bar'),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NordicColors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: NordicColors.secondaryFixed,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: MIcon(
                                          Symbols.electric_car,
                                          size: 20,
                                          color: NordicColors.onSecondaryFixed,
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
                                            'Confirm destination',
                                            style: NordicText.titleSm.copyWith(
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            '${Fmt.distance(tripMeters!.round())} · ~${Fmt.duration(estimateDurationSeconds(tripMeters))} (estimate)',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: NordicText.bodySm.copyWith(
                                              color:
                                                  NordicColors.primaryFixedDim,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              key: const Key('search_next'),
                              onTap: _next,
                              child: Elevated(
                                shadows: Tw.md,
                                radius: 8,
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: NordicColors.secondary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Next',
                                        style: NordicText.titleSm.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const MIcon(
                                        Symbols.arrow_forward,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  const _RouteField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.active,
    required this.marker,
    required this.onChanged,
    required this.hint,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool active;
  final Widget marker;
  final Widget? trailing;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Elevated(
      shadows: active ? Tw.sm : const [],
      radius: 8,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active
              ? NordicColors.surfaceContainerLowest
              : NordicColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? [Tw.ring(NordicColors.secondaryFixedDim)] : null,
        ),
        child: Row(
          children: [
            SizedBox(width: 20, height: 20, child: Center(child: marker)),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: NordicText.labelSm.copyWith(
                        color: active
                            ? NordicColors.secondary
                            : NordicColors.onSurfaceVariant,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      maxLines: 1,
                      style: NordicText.titleSm.copyWith(
                        color: NordicColors.onSurface,
                      ),
                      cursorColor: NordicColors.secondary,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: hint,
                        hintStyle: NordicText.titleSm.copyWith(
                          color: NordicColors.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.place,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Place? place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Elevated(
      shadows: Tw.sm,
      radius: 12,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NordicColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Center(child: MIcon(icon, size: 22, color: iconColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NordicText.titleSm.copyWith(
                      color: NordicColors.onSurface,
                    ),
                  ),
                  Text(
                    place?.name ?? 'Set location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NordicText.bodySm.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
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

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.place,
    required this.first,
    required this.from,
    required this.onTap,
  });

  final Place place;
  final bool first;
  final LatLng? from;
  final VoidCallback onTap;

  static IconData _icon(Place p) {
    if (p.id == 'holmenkollen') return Symbols.downhill_skiing;
    return switch (p.kind) {
      PlaceKind.airport => Symbols.flight,
      PlaceKind.transit => Symbols.train,
      PlaceKind.museum => Symbols.museum,
      PlaceKind.landmark => Symbols.account_balance,
      PlaceKind.business => Symbols.business_center,
      PlaceKind.home => Symbols.home,
      PlaceKind.work => Symbols.apartment,
      PlaceKind.pin => Symbols.push_pin,
      PlaceKind.address => Symbols.location_on,
    };
  }

  @override
  Widget build(BuildContext context) {
    final meters = from == null ? null : haversineMeters(from!, place.position);
    return GestureDetector(
      key: Key('result_${place.id}'),
      onTap: onTap,
      child: Elevated(
        shadows: Tw.sm,
        radius: 12,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NordicColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: first
                            ? NordicColors.surfaceContainerHigh
                            : NordicColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: MIcon(
                          _icon(place),
                          size: 20,
                          color: NordicColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NordicText.titleSm.copyWith(
                              color: NordicColors.onSurface,
                            ),
                          ),
                          Text(
                            place.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NordicText.bodySm.copyWith(
                              color: NordicColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (meters != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.distance(meters.round()),
                      style: NordicText.titleSm.copyWith(
                        color: NordicColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MIcon(
                          Symbols.schedule,
                          size: 12,
                          color: NordicColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${(estimateDurationSeconds(meters) / 60).ceil()}m',
                          style: NordicText.labelSm.copyWith(
                            color: NordicColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
