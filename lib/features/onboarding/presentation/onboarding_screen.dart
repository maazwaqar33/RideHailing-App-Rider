import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../shared/stitch.dart';
import '../application/onboarding_provider.dart';

/// Stitch `onboarding_1_book_in_seconds`, `onboarding_2_track_live`, `onboarding_3_pay_your_way`.
/// The illustrations are marketing visuals taken from the design (sample fare, sample driver);
/// nothing on them is live data.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go('/welcome');
  }

  void _next(int page) {
    if (page >= 2) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: SafeArea(
        child: PageView(
          controller: _controller,
          children: [
            _OnboardingPage1(onSkip: _finish, onNext: () => _next(0)),
            _OnboardingPage2(onSkip: _finish, onNext: () => _next(1)),
            _OnboardingPage3(onSkip: _finish, onNext: () => _next(2)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _PageShell extends StatelessWidget {
  const _PageShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int active;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: i == active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ],
    ],
  );
}

class _Cta extends StatelessWidget {
  const _Cta({
    required this.label,
    required this.onPressed,
    required this.radius,
    this.key2,
  });

  final String label;
  final VoidCallback onPressed;
  final double radius;
  final Key? key2;

  @override
  Widget build(BuildContext context) => StitchButton(
    key: key2,
    label: label,
    icon: Symbols.arrow_forward,
    onPressed: onPressed,
    radius: radius,
  );
}

// ---------------------------------------------------------------------------
// Page 1: Book in seconds
// ---------------------------------------------------------------------------

class _OnboardingPage1 extends StatelessWidget {
  const _OnboardingPage1({required this.onSkip, required this.onNext});

  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: NordicColors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'OSLO MOBILITY',
                    style: NordicText.labelSm.copyWith(
                      color: NordicColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10 * 0.05,
                    ),
                  ),
                ],
              ),
              TextButton(
                key: const Key('onboarding_skip'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: NordicColors.onSurfaceVariant,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Skip',
                  style: NordicText.labelLg.copyWith(
                    color: NordicColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Illustration card
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Elevated(
            shadows: Tw.sm,
            radius: 12,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NordicColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -64 - 16,
                    right: -64 - 16,
                    child: Blob(
                      size: 176,
                      color: Tw.a(NordicColors.secondaryContainer, 0.2),
                      blur: 64,
                    ),
                  ),
                  Positioned(
                    bottom: -40 - 16,
                    left: -40 - 16,
                    child: Blob(
                      size: 144,
                      color: Tw.a(NordicColors.surfaceContainerHigh, 0.4),
                      blur: 40,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Elevated(
                        shadows: Tw.sm,
                        radius: 8,
                        child: Container(
                          height: 176,
                          decoration: BoxDecoration(
                            color: NordicColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.6,
                                  child: CustomPaint(
                                    painter: _SkylinePainter(),
                                  ),
                                ),
                              ),
                              const _SampleFareCard(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Elevated(
                        shadows: Tw.sm,
                        radius: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Tw.a(
                              NordicColors.surfaceContainerLowest,
                              0.8,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: NordicColors.primaryFixed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: MIcon(
                                    Symbols.lock,
                                    size: 16,
                                    color: NordicColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No Surge Surprises',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: NordicText.labelMd.copyWith(
                                        color: NordicColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Locked fares remain unaffected by traffic.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: NordicText.labelSm.copyWith(
                                        color: NordicColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const MIcon(
                                Symbols.check_circle,
                                size: 18,
                                lh: 28,
                                color: NordicColors.secondary,
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
        ),
        // Editorial typography
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
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
                      Symbols.verified,
                      size: 14,
                      lh: 20,
                      color: NordicColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'NORDIC PRECISION',
                      style: NordicText.labelSm.copyWith(
                        color: NordicColors.onSurface,
                        letterSpacing: 10 * 0.05,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Book in seconds',
                textAlign: TextAlign.center,
                style: NordicText.displayLgMobile.copyWith(
                  color: NordicColors.primary,
                  letterSpacing: 32 * -0.025,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'See a transparent fare estimate before you confirm every ride.',
                  textAlign: TextAlign.center,
                  style: NordicText.bodyMd.copyWith(
                    color: NordicColors.onSurfaceVariant,
                    height: 26 / 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Dots(
          active: 0,
          activeColor: NordicColors.secondary,
          inactiveColor: NordicColors.outlineVariant,
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _Cta(
            key2: const Key('onboarding_next'),
            label: 'Next',
            onPressed: onNext,
            radius: 12,
          ),
        ),
      ],
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 320;
    final sy = size.height / 180;
    Path p(List<(double, double)> pts) {
      final path = Path()..moveTo(pts.first.$1 * sx, pts.first.$2 * sy);
      for (final q in pts.skip(1)) {
        path.lineTo(q.$1 * sx, q.$2 * sy);
      }
      return path..close();
    }

    canvas.drawPath(
      p([
        (0, 130),
        (35, 110),
        (70, 125),
        (120, 90),
        (170, 115),
        (220, 85),
        (270, 110),
        (320, 95),
        (320, 180),
        (0, 180),
      ]),
      Paint()..color = NordicColors.surfaceContainer,
    );
    canvas.drawPath(
      p([
        (0, 145),
        (40, 135),
        (90, 148),
        (150, 128),
        (210, 142),
        (280, 120),
        (320, 130),
        (320, 180),
        (0, 180),
      ]),
      Paint()..color = const Color(0xFFEFF4FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SampleFareCard extends StatelessWidget {
  const _SampleFareCard();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: SizedBox(
        width: double.infinity,
        child: Elevated(
          shadows: Tw.md,
          radius: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NordicColors.secondaryFixed,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MIcon(
                              Symbols.bolt,
                              size: 14,
                              fill: 1,
                              color: NordicColors.onSecondaryFixedVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Live status',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.onSecondaryFixedVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              color: NordicColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            'Live Route',
                            style: NordicText.labelSm.copyWith(
                              color: NordicColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: NordicColors.secondaryFixedDim,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: NordicColors.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 24,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: NordicColors.outlineVariant,
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: NordicColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Oslo S',
                                    style: NordicText.labelMd.copyWith(
                                      color: NordicColors.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Departing now',
                                    style: NordicText.labelSm.copyWith(
                                      color: NordicColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Aker Brygge',
                                    style: NordicText.labelMd.copyWith(
                                      color: NordicColors.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '6 min ride',
                                    style: NordicText.labelSm.copyWith(
                                      color: NordicColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTIMATED FARE',
                            style: NordicText.labelSm.copyWith(
                              color: NordicColors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'EUR 17.44',
                            style: NordicText.currencyDisplay.copyWith(
                              color: NordicColors.primary,
                              letterSpacing: 22 * -0.025,
                            ),
                          ),
                        ],
                      ),
                      Elevated(
                        shadows: Tw.sm,
                        radius: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: NordicColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const MIcon(
                                Symbols.electric_car,
                                size: 14,
                                fill: 1,
                                color: NordicColors.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'EV',
                                style: NordicText.labelSm.copyWith(
                                  color: NordicColors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: Track your driver live
// ---------------------------------------------------------------------------

class _OnboardingPage2 extends StatelessWidget {
  const _OnboardingPage2({required this.onSkip, required this.onNext});

  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const MIcon(
                    Symbols.eco,
                    size: 16,
                    fill: 1,
                    color: NordicColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '100% ELECTRIC',
                    style: NordicText.labelMd.copyWith(
                      color: NordicColors.secondary,
                      letterSpacing: 12 * 0.05,
                    ),
                  ),
                ],
              ),
              InkWell(
                key: const Key('onboarding_skip'),
                onTap: onSkip,
                borderRadius: BorderRadius.circular(9999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    'Skip',
                    style: NordicText.labelLg.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Elevated(
            shadows: Tw.md,
            radius: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3.5,
                child: ColoredBox(
                  color: NordicColors.surfaceContainer,
                  child: const _TrackMap(),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: NordicColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MIcon(
                      Symbols.my_location,
                      size: 14,
                      lh: 20,
                      fill: 1,
                      color: NordicColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live status updates',
                      style: NordicText.labelMd.copyWith(
                        color: NordicColors.onPrimaryFixedVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Track your driver live',
                textAlign: TextAlign.center,
                style: NordicText.headlineLg.copyWith(
                  color: NordicColors.primary,
                  letterSpacing: 28 * -0.025,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'Follow your ride from request to arrival with live GPS tracking on the interactive map.',
                  textAlign: TextAlign.center,
                  style: NordicText.bodyMd.copyWith(
                    color: NordicColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const _Dots(
          active: 1,
          activeColor: NordicColors.secondary,
          inactiveColor: NordicColors.surfaceContainerHighest,
        ),
        const SizedBox(height: 24),
        _Cta(
          key2: const Key('onboarding_next'),
          label: 'Next',
          onPressed: onNext,
          radius: 8,
        ),
      ],
    );
  }
}

class _TrackMap extends StatelessWidget {
  const _TrackMap();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(
                DesignAssets.mapLive,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            // from-primary/30 via-transparent to-primary/10, direction: to top
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Tw.a(NordicColors.primary, 0.3),
                      Tw.a(NordicColors.primary, 0),
                      Tw.a(NordicColors.primary, 0.1),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
            // HUD
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Elevated(
                    shadows: Tw.lg,
                    radius: 9999,
                    child: BackdropBlur(
                      radius: 9999,
                      blur: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: Tw.a(NordicColors.surfaceContainerLowest, 0.95),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: NordicColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ETA 3 min',
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '•',
                              style: NordicText.bodySm.copyWith(
                                color: NordicColors.outline,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '0.8 km',
                              style: NordicText.bodySm.copyWith(
                                color: NordicColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Elevated(
                    shadows: Tw.md,
                    radius: 9999,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: NordicColors.primaryContainer,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MIcon(
                            Symbols.navigation,
                            size: 12,
                            lh: 16,
                            color: NordicColors.secondaryFixed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'KARL JOHAN',
                            style: NordicText.labelSm.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Destination landmark pill
            Positioned(
              top: 32,
              right: 32,
              child: Elevated(
                shadows: Tw.md,
                radius: 9999,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: NordicColors.primary,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MIcon(
                        Symbols.flag,
                        size: 10,
                        fill: 1,
                        color: NordicColors.secondaryFixed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Aker Brygge',
                        style: NordicText.labelSm.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // "You" marker
            Positioned(
              bottom: 24,
              left: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Elevated(
                    shadows: Tw.lg,
                    circle: true,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: NordicColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: NordicColors.secondaryFixed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Elevated(
                    shadows: Tw.sm,
                    radius: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: NordicColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'You',
                        style: NordicText.labelSm.copyWith(
                          color: NordicColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Driver beacon at (53%, 42%)
            Positioned(
              // left-[53%] top-[42%] in the HTML; the beacon is animated by script and the screenshot
              // caught it ~7 px up-left of that point, so match the screenshot.
              left: w * 0.53 - 7,
              top: h * 0.42 + 7,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -12,
                          right: -12,
                          top: -12,
                          bottom: -12,
                          child: Blurred(
                            sigma: 12,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Tw.a(
                                  NordicColors.secondaryFixedDim,
                                  0.4,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        Elevated(
                          shadows: Tw.xl,
                          circle: true,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: NordicColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: MIcon(
                                Symbols.directions_car,
                                size: 20,
                                fill: 1,
                                color: NordicColors.secondaryFixed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Elevated(
                      shadows: Tw.lg,
                      radius: 9999,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: NordicColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Polestar 2',
                              style: NordicText.labelMd.copyWith(
                                color: NordicColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                              'EL 84920',
                              style: NordicText.labelMd.copyWith(
                                color: NordicColors.onSurfaceVariant,
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
          ],
        );
      },
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 340;
    final sy = size.height / 300;
    Offset o(double x, double y) => Offset(x * sx, y * sy);
    final full = Path()
      ..moveTo(50 * sx, 260 * sy)
      ..cubicTo(110 * sx, 230 * sy, 140 * sx, 190 * sy, 190 * sx, 140 * sy)
      ..cubicTo(230 * sx, 100 * sy, 270 * sx, 80 * sy, 290 * sx, 45 * sy);
    final bounds = full.getBounds();
    final shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x334FDBC8), Color(0xCC006B5F), Color(0xFF00152F)],
      stops: [0, 0.6, 1],
    ).createShader(bounds);
    final dots = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final PathMetric m in full.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        final seg = m.extractPath(d, math.min(d + 1, m.length));
        canvas.drawPath(seg, dots);
      }
    }
    final solid = Path()
      ..moveTo(o(50, 260).dx, o(50, 260).dy)
      ..cubicTo(110 * sx, 230 * sy, 140 * sx, 190 * sy, 190 * sx, 140 * sy);
    canvas.drawPath(
      solid,
      Paint()
        ..color = NordicColors.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Page 3: Pay your way
// ---------------------------------------------------------------------------

class _OnboardingPage3 extends StatefulWidget {
  const _OnboardingPage3({required this.onSkip, required this.onNext});

  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  State<_OnboardingPage3> createState() => _OnboardingPage3State();
}

class _OnboardingPage3State extends State<_OnboardingPage3> {
  @override
  Widget build(BuildContext context) {
    return _PageShell(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: NordicColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  'STEP 3 OF 3',
                  style: NordicText.labelSm.copyWith(
                    color: NordicColors.onSurfaceVariant,
                    letterSpacing: 10 * 0.05,
                  ),
                ),
              ),
              InkWell(
                key: const Key('onboarding_skip'),
                onTap: widget.onSkip,
                borderRadius: BorderRadius.circular(9999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    'Skip',
                    style: NordicText.labelMd.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LayoutBuilder(
            builder: (context, c) {
              final h = math.min(c.maxWidth * 3 / 4, 288.0);
              return Elevated(
                shadows: Tw.sm,
                radius: 12,
                child: Container(
                  height: h,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -48 - 16,
                        right: -48 - 16,
                        child: Blob(
                          size: 192,
                          color: Tw.a(NordicColors.secondaryFixed, 0.3),
                          blur: 64,
                        ),
                      ),
                      Positioned(
                        bottom: -32 - 16,
                        left: -32 - 16,
                        child: Blob(
                          size: 160,
                          color: Tw.a(NordicColors.surfaceVariant, 0.4),
                          blur: 40,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.4,
                            child: Center(
                              child: SizedBox(
                                width: 280,
                                height: 120,
                                child: CustomPaint(painter: _PayRoutePainter()),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Transform.translate(
                              offset: const Offset(0, 4),
                              child: Transform.rotate(
                                angle: 1 * math.pi / 180,
                                child: _debitBadge(),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _cashBadge(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MIcon(
                      Symbols.verified_user,
                      size: 18,
                      fill: 1,
                      color: NordicColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FRICTIONLESS MOBILITY',
                      style: NordicText.labelMd.copyWith(
                        color: NordicColors.secondary,
                        letterSpacing: 12 * 0.05,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Pay your way',
                style: NordicText.displayLgMobile.copyWith(
                  color: NordicColors.primary,
                  letterSpacing: 32 * -0.025,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose between card or paying the driver in cash with flexible checkout.',
                style: NordicText.bodyMd.copyWith(
                  color: NordicColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: [
              Expanded(
                child: _method(
                  Symbols.credit_card,
                  NordicColors.primary,
                  'Card',
                  'Online',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _method(
                  Symbols.payments,
                  NordicColors.secondary,
                  'Cash',
                  'To driver',
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: _Dots(
            active: 2,
            activeColor: NordicColors.secondaryFixedDim,
            inactiveColor: NordicColors.outlineVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _Cta(
            key2: const Key('onboarding_next'),
            label: 'Get started',
            onPressed: widget.onNext,
            radius: 8,
          ),
        ),
      ],
    );
  }

  Widget _method(IconData icon, Color color, String title, String sub) =>
      Elevated(
        shadows: Tw.sm,
        radius: 12,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NordicColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              MIcon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                title,
                style: NordicText.titleSm.copyWith(color: NordicColors.primary),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: NordicText.labelSm.copyWith(
                  color: NordicColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _debitBadge() => Elevated(
    shadows: Tw.md,
    radius: 8,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NordicColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: NordicColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: MIcon(
                Symbols.credit_card,
                size: 18,
                color: NordicColors.secondaryFixed,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Credit Card',
                    style: NordicText.titleSm.copyWith(
                      color: NordicColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Visa',
                      style: NordicText.labelSm.copyWith(
                        color: NordicColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Not charged',
                style: NordicText.labelSm.copyWith(
                  color: NordicColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _cashBadge() => Elevated(
    shadows: Tw.sm,
    radius: 8,
    child: BackdropBlur(
      radius: 8,
      blur: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: Tw.a(NordicColors.surfaceContainerLowest, 0.95),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: NordicColors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: MIcon(
                  Symbols.payments,
                  size: 16,
                  color: NordicColors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cash on arrival',
              style: NordicText.labelLg.copyWith(color: NordicColors.onSurface),
            ),
            const SizedBox(width: 8),
            Text(
              'EUR',
              style: NordicText.labelSm.copyWith(
                color: NordicColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PayRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(20, 100)
      ..cubicTo(90, 10, 190, 110, 260, 20);
    final paint = Paint()
      ..color = NordicColors.secondaryFixedDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
