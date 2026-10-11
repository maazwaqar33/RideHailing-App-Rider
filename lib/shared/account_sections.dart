import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../features/map/application/map_providers.dart';
import '../features/map/data/local_places_store.dart';
import 'profile_sections.dart';
import 'stitch.dart';

/// Saved places (Home / Work). REAL but device-local (SharedPreferences); the backend has no
/// saved-places endpoint. [keyPrefix] keeps widget keys unique when two tabs show the section.
class SavedPlacesSection extends ConsumerStatefulWidget {
  const SavedPlacesSection({super.key, required this.keyPrefix});

  final String keyPrefix;

  @override
  ConsumerState<SavedPlacesSection> createState() => _SavedPlacesSectionState();
}

class _SavedPlacesSectionState extends ConsumerState<SavedPlacesSection> {
  Future<void> _edit(String slot) async {
    await context.push('/search?set=$slot');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(localPlacesStoreProvider);
    final home = store.saved(SavedSlot.home);
    final work = store.saved(SavedSlot.work);
    final p = widget.keyPrefix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Saved Places'),
        const SizedBox(height: 8),
        ListCard(
          children: [
            IconRow(
              key: Key('${p}_home'),
              icon: Symbols.home,
              title: 'Home',
              subtitle: home?.address.isNotEmpty == true
                  ? home!.address
                  : (home?.name ?? 'Not set'),
              onTap: () => _edit('home'),
              trailing: const MIcon(
                Symbols.edit,
                size: 20,
                color: NordicColors.outlineVariant,
              ),
            ),
            IconRow(
              key: Key('${p}_work'),
              icon: Symbols.business,
              title: 'Work',
              subtitle: work?.address.isNotEmpty == true
                  ? work!.address
                  : (work?.name ?? 'Not set'),
              onTap: () => _edit('work'),
              trailing: const MIcon(
                Symbols.edit,
                size: 20,
                color: NordicColors.outlineVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// `Nordic Ride v… (Oslo, Norway)` line.
class VersionLine extends StatelessWidget {
  const VersionLine({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Nordic Ride v1.0.0 (Oslo)',
      style: NordicText.labelSm.copyWith(color: NordicColors.outline),
    ),
  );
}
