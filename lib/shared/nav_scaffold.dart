import 'package:flutter/material.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import 'stitch.dart';

const double kHeaderHeight = 64;
const double kNavHeight = 64;

/// Stitch tab chrome: fixed translucent header (logo, "Nordic Ride", section label, avatar) and the
/// fixed bottom navigation (Ride / Trips / Wallet / Profile). The body is laid out between them with
/// the design's `pt-16 pb-20` insets.
class StitchNavScaffold extends StatelessWidget {
  const StitchNavScaffold({
    super.key,
    required this.index,
    required this.onSelect,
    required this.sectionLabel,
    required this.body,
    required this.userName,
    this.onAvatarTap,
    this.backgroundColor = NordicColors.surface,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final String sectionLabel;
  final Widget body;
  final String userName;
  final VoidCallback? onAvatarTap;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: kHeaderHeight + pad.top,
                bottom: 80 + pad.bottom,
              ),
              child: body,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Header(
              label: sectionLabel,
              userName: userName,
              onAvatarTap: onAvatarTap,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNav(index: index, onSelect: onSelect),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.label,
    required this.userName,
    this.onAvatarTap,
  });

  final String label;
  final String userName;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F2A4A),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: BackdropBlur(
        radius: 0,
        blur: 24,
        child: Container(
          color: Tw.a(NordicColors.surface, 0.8),
          padding: EdgeInsets.only(top: top),
          child: SizedBox(
            height: kHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const NordicLogoMark(size: 32),
                      const SizedBox(width: 8),
                      Text(
                        'Nordic Ride',
                        style: NordicText.titleSm.copyWith(
                          color: NordicColors.primary,
                          letterSpacing: 16 * -0.025,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        label,
                        key: const Key('header_section_label'),
                        style: NordicText.labelMd.copyWith(
                          color: NordicColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        key: const Key('header_avatar'),
                        onTap: onAvatarTap,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: const RiderAvatar(size: 32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Symbols.local_taxi, 'Ride'),
    (Symbols.route, 'Trips'),
    (Symbols.account_balance_wallet, 'Wallet'),
    (Symbols.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      key: const Key('bottom_nav'),
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0F2A4A),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: BackdropBlur(
        radius: 0,
        blur: 24,
        child: Container(
          color: Tw.a(NordicColors.surface, 0.85),
          padding: EdgeInsets.only(bottom: bottom),
          child: SizedBox(
            height: kNavHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < _items.length; i++)
                    InkWell(
                      onTap: () => onSelect(i),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 56,
                          minHeight: 44,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // text-2xl on the glyph span: 24 px font, 32 px line box.
                            MIcon(
                              _items[i].$1,
                              size: 24,
                              lh: 32,
                              color: i == index
                                  ? NordicColors.secondary
                                  : NordicColors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _items[i].$2,
                              style: NordicText.labelSm.copyWith(
                                color: i == index
                                    ? NordicColors.secondary
                                    : NordicColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stitch top bar of the pushed (non-tab) screens: back arrow, title and the round "person" avatar.
class StitchBackHeader extends StatelessWidget {
  const StitchBackHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.backKey,
    this.showLogo = false,
    this.userName,
    this.iosBack = false,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Key? backKey;

  /// Tracking screens: logo before the title and the rider avatar (with ring) on the right.
  final bool showLogo;
  final String? userName;

  /// `arrow_back_ios_new` instead of `arrow_back` (tracking screens).
  final bool iosBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: BackdropBlur(
        radius: 0,
        blur: 24,
        child: Container(
          color: Tw.a(NordicColors.surface, 0.8),
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          child: SizedBox(
            height: kHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Transform.translate(
                          offset: const Offset(-4, 0),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              key: backKey ?? const Key('header_back'),
                              tooltip: 'Go Back',
                              padding: EdgeInsets.zero,
                              onPressed: onBack,
                              icon: MIcon(
                                iosBack
                                    ? Symbols.arrow_back_ios_new
                                    : Symbols.arrow_back,
                                size: iosBack ? 24 : 24,
                                color: iosBack
                                    ? NordicColors.primary
                                    : NordicColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                        if (showLogo) ...[
                          const NordicLogoMark(size: 32),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: NordicText.titleSm.copyWith(
                              color: showLogo
                                  ? NordicColors.primary
                                  : NordicColors.onSurface,
                              letterSpacing: showLogo ? 0 : 16 * -0.025,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (userName != null)
                    const RiderAvatar(size: 32)
                  else
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: NordicColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: MIcon(
                          Symbols.person,
                          size: 18,
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
    );
  }
}
