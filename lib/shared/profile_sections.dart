import 'package:flutter/material.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../features/auth/domain/auth_models.dart';
import 'stitch.dart';

/// Shadow used by the profile/wallet cards: `shadow-[0_4px_16px_-2px_rgba(15,42,74,0.06)]`.
const List<BoxShadow> kSoftCardShadow = [
  BoxShadow(
    color: Color(0x0F0F2A4A),
    blurRadius: 16,
    spreadRadius: -2,
    offset: Offset(0, 4),
  ),
];

/// Section heading (`font-title-sm text-primary font-semibold px-1`).
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: NordicText.titleSm.copyWith(
            color: NordicColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// White `rounded-xl` list card that clips its rows.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: kSoftCardShadow,
    radius: 12,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        color: NordicColors.surfaceContainerLowest,
        padding: padding,
        child: Column(children: children),
      ),
    ),
  );
}

/// A `p-space-md` row: 40 px rounded icon tile, title + subtitle, trailing control.
class IconRow extends StatelessWidget {
  const IconRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconBackground = NordicColors.surfaceContainer,
    this.iconColor = NordicColors.primary,
    this.titleExtra,
    this.padded = true,
    this.opacity = 1,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconBackground;
  final Color iconColor;
  final Widget? titleExtra;
  final bool padded;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: MIcon(icon, size: 24, color: iconColor)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: NordicText.titleSm.copyWith(
                              color: NordicColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (titleExtra != null) ...[
                          const SizedBox(width: 8),
                          titleExtra!,
                        ],
                      ],
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
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
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padded ? const EdgeInsets.all(16) : EdgeInsets.zero,
          child: row,
        ),
      ),
    );
  }
}

/// Profile card: avatar with verified badge, name, role pill, email, phone.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.user,
    this.nameKey,
    this.emailKey,
  });

  final AuthUser? user;
  final Key? nameKey;
  final Key? emailKey;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    return Elevated(
      shadows: kSoftCardShadow,
      radius: 12,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NordicColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const PhotoCircle(
                  DemoPhotos.rider,
                  size: 64,
                  semanticLabel: 'Profile photo',
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name,
                        key: nameKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NordicText.titleSm.copyWith(
                          color: NordicColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NordicColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MIcon(
                              Symbols.eco,
                              size: 12,
                              lh: 14,
                              color: NordicColors.secondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Rider',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    user?.email ?? '',
                    key: emailKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NordicText.bodySm.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                  if (user?.phone != null && user!.phone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        user!.phone!,
                        style: NordicText.labelMd.copyWith(
                          color: NordicColors.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
