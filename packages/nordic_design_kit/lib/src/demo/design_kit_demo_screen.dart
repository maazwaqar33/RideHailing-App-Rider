import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import '../widgets/nordic_bottom_sheet.dart';
import '../widgets/nordic_button.dart';
import '../widgets/nordic_card.dart';
import '../widgets/nordic_components.dart';
import '../widgets/nordic_feedback.dart';
import '../widgets/nordic_loaders.dart';
import '../widgets/nordic_rating_stars.dart';
import '../widgets/nordic_text_field.dart';

/// Showcase of every design-kit component. Reachable in the Rider app from
/// Profile -> Design kit, and usable as a standalone screen by other apps.
class DesignKitDemoScreen extends StatefulWidget {
  const DesignKitDemoScreen({super.key});

  @override
  State<DesignKitDemoScreen> createState() => _DesignKitDemoScreenState();
}

class _DesignKitDemoScreenState extends State<DesignKitDemoScreen> {
  bool _loading = false;
  bool _checked = false;
  bool _chip = true;
  int _seg = 0;
  int _rating = 3;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _simulateLoading() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _loading = false);
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: NordicSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: NordicText.labelMd.copyWith(color: NordicColors.textSecondary),
        ),
        const SizedBox(height: NordicSpacing.sm + 4),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design kit')),
      body: ListView(
        key: const Key('design_kit_list'),
        padding: const EdgeInsets.all(NordicSpacing.gutterMobile),
        children: [
          _section(
            'Colours',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in {
                  'primary': NordicColors.primaryContainer,
                  'secondary': NordicColors.secondary,
                  'secondary-container': NordicColors.secondaryContainer,
                  'accent teal': NordicColors.accentTeal,
                  'surface': NordicColors.surface,
                  'error': NordicColors.error,
                  'outline': NordicColors.outline,
                }.entries)
                  Column(
                    children: [
                      Container(
                        width: 64,
                        height: 40,
                        decoration: BoxDecoration(
                          color: e.value,
                          borderRadius: NordicRadii.controlRadius,
                          border: Border.all(color: NordicColors.border),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(e.key, style: NordicText.bodySm),
                    ],
                  ),
              ],
            ),
          ),
          _section(
            'Typography (Inter)',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display LG 32', style: NordicText.displayLgMobile),
                Text('Headline SM 20', style: NordicText.headlineSm),
                Text('Title MD 16', style: NordicText.titleMd),
                Text(
                  'Body MD 14 - The quick brown fox',
                  style: NordicText.bodyMd,
                ),
                Text('LABEL CAPS 11', style: NordicText.labelMd),
                Text(
                  'Tabular 1 111,00 / 8 888,88',
                  style: NordicText.tabular(NordicText.currencyDisplay),
                ),
              ],
            ),
          ),
          _section(
            'Buttons',
            Column(
              children: [
                NordicButton(label: 'Primary', onPressed: () {}),
                const SizedBox(height: 8),
                NordicButton(
                  label: 'Secondary (teal)',
                  onPressed: () {},
                  variant: NordicButtonVariant.secondary,
                ),
                const SizedBox(height: 8),
                NordicButton(
                  label: 'Tertiary',
                  onPressed: () {},
                  variant: NordicButtonVariant.tertiary,
                ),
                const SizedBox(height: 8),
                NordicButton(
                  label: 'Destructive',
                  onPressed: () {},
                  variant: NordicButtonVariant.destructive,
                ),
                const SizedBox(height: 8),
                NordicButton(label: 'Disabled', onPressed: null),
                const SizedBox(height: 8),
                NordicButton(
                  label: _loading ? 'Loading' : 'Tap to load (2 s)',
                  isLoading: _loading,
                  icon: Icons.bolt,
                  onPressed: _simulateLoading,
                  variant: NordicButtonVariant.secondary,
                ),
              ],
            ),
          ),
          _section(
            'Inputs',
            Column(
              children: [
                NordicTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _controller,
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 12),
                const NordicTextField(
                  label: 'Password',
                  obscureText: true,
                  hint: 'At least 10 characters',
                ),
                const SizedBox(height: 12),
                const NordicTextField(
                  label: 'With error',
                  errorText: 'This field is required',
                ),
                const SizedBox(height: 12),
                NordicCheckboxRow(
                  value: _checked,
                  onChanged: (v) => setState(() => _checked = v),
                  label: Text(
                    'I agree to the Terms and Privacy Policy',
                    style: NordicText.bodyMd,
                  ),
                ),
              ],
            ),
          ),
          _section(
            'Cards',
            Column(
              children: [
                NordicCard(
                  child: Text('Flat card (Level 1)', style: NordicText.bodyMd),
                ),
                const SizedBox(height: 8),
                NordicCard(
                  elevated: true,
                  child: Text(
                    'Elevated card (Level 2)',
                    style: NordicText.bodyMd,
                  ),
                ),
                const SizedBox(height: 8),
                NordicCard(
                  selected: true,
                  child: Text('Selected card', style: NordicText.bodyMd),
                ),
              ],
            ),
          ),
          _section(
            'Badges and banners',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NordicStatusBadge(
                      label: 'Completed',
                      tone: NordicTone.success,
                    ),
                    NordicStatusBadge(
                      label: 'Requested',
                      tone: NordicTone.pending,
                    ),
                    NordicStatusBadge(
                      label: 'Cancelled',
                      tone: NordicTone.critical,
                    ),
                    NordicStatusBadge(label: 'Info', tone: NordicTone.info),
                    NordicMockBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                const NordicBanner(
                  message: 'Location permission denied, showing Oslo.',
                  title: 'Info',
                ),
                const SizedBox(height: 8),
                const NordicBanner(
                  message: 'Estimate is a mock.',
                  tone: NordicTone.pending,
                  title: 'Mock data',
                ),
                const SizedBox(height: 8),
                const NordicBanner(
                  message: 'Network unreachable.',
                  tone: NordicTone.critical,
                ),
              ],
            ),
          ),
          _section(
            'Brand, pills, chips, tabs',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NordicLogo(size: 72),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NordicPill(
                      label: 'Oslo - Zero emission',
                      dot: true,
                      uppercase: true,
                    ),
                    NordicPill(label: 'Silent EV', icon: Icons.bolt),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    NordicChip(
                      label: 'Punctual',
                      selected: _chip,
                      onTap: () => setState(() => _chip = !_chip),
                    ),
                    NordicChip(
                      label: 'Quiet ride',
                      selected: !_chip,
                      onTap: () => setState(() => _chip = !_chip),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                NordicSegmented(
                  labels: const ['Past trips', 'Scheduled'],
                  index: _seg,
                  onChanged: (v) => setState(() => _seg = v),
                ),
                const SizedBox(height: 12),
                const NordicStepProgress(step: 1, total: 3),
                const SizedBox(height: 12),
                const NordicRouteSummary(
                  pickupLabel: 'Oslo S',
                  dropoffLabel: 'Aker Brygge',
                ),
                const SizedBox(height: 12),
                const NordicListTile(
                  icon: Icons.home_outlined,
                  title: 'Home',
                  subtitle: 'Frognerveien 14',
                ),
                const SizedBox(height: 12),
                NordicFloatingButton(icon: Icons.my_location, onTap: () {}),
              ],
            ),
          ),
          _section(
            'Rating stars',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NordicRatingStars(
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: 8),
                const NordicRatingStars(value: 4, size: 20),
              ],
            ),
          ),
          _section(
            'Loaders and skeletons',
            const Column(
              children: [
                NordicLoader(message: 'Loading...'),
                SizedBox(height: 12),
                NordicSkeletonRow(),
                NordicSkeletonRow(),
              ],
            ),
          ),
          _section(
            'Avatar',
            const Row(
              children: [
                NordicAvatar(name: 'Kari Hansen'),
                SizedBox(width: 12),
                NordicAvatar(name: 'Lars', size: 32),
              ],
            ),
          ),
          _section(
            'Bottom sheet',
            NordicButton(
              label: 'Open bottom sheet',
              variant: NordicButtonVariant.tertiary,
              onPressed: () => showNordicBottomSheet<void>(
                context: context,
                title: 'Example sheet',
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sheets use a 16px top radius and a drag handle.',
                      style: NordicText.bodyMd,
                    ),
                    const SizedBox(height: 16),
                    NordicButton(
                      label: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _ErrorViewDemo(),
        ],
      ),
    );
  }
}

class _ErrorViewDemo extends StatelessWidget {
  const _ErrorViewDemo();

  @override
  Widget build(BuildContext context) {
    return const NordicCard(
      child: SizedBox(
        height: 200,
        child: NordicErrorView(message: 'We could not reach the server.'),
      ),
    );
  }
}
