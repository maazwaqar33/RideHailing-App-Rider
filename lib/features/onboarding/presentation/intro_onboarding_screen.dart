import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../shared/stitch.dart';
import '../application/onboarding_provider.dart';

/// Stitch `splash_onboarding`: the single-screen onboarding carousel (brand bar with Skip, three
/// illustrated slides, page dots, "Continue" and "Already have an account? Sign In"). It is the
/// alternate to the three-page `onboarding_1/2/3` flow, reachable at `/intro` (and the default
/// first-run entry with `--dart-define=UI_VARIANT=hub`).
///
/// The slide illustrations are marketing visuals: the sample fare, driver and PIN are static
/// examples (DEMO). The design's Norwegian copy and NOK/Vipps/BankID claims are replaced with
/// English text that matches what the app really does.
class IntroOnboardingScreen extends ConsumerStatefulWidget {
  const IntroOnboardingScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  ConsumerState<IntroOnboardingScreen> createState() =>
      _IntroOnboardingScreenState();
}

class _IntroOnboardingScreenState extends ConsumerState<IntroOnboardingScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
  );
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({required String to}) async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go(to);
  }

  void _next() {
    if (_page >= 2) {
      _finish(to: '/welcome');
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
        child: Stack(
          children: [
            Positioned(
              top: -96,
              left: 0,
              right: 0,
              child: Center(
                child: Blob(
                  size: 320,
                  color: Tw.a(NordicColors.secondaryContainer, 0.2),
                  blur: 64,
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Elevated(
                            shadows: Tw.sm,
                            radius: 12,
                            child: Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: NordicColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const NordicLogoMark(size: 28),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nordic Ride',
                                style: NordicText.titleSm.copyWith(
                                  color: NordicColors.onSurface,
                                  letterSpacing: 16 * -0.025,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: NordicColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Oslo sentrum',
                                    style: NordicText.labelSm.copyWith(
                                      color: NordicColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        key: const Key('intro_skip'),
                        onTap: () => _finish(to: '/welcome'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
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
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: const [_Slide1(), _Slide2(), _Slide3()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: i == _page ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? NordicColors.primary
                                : NordicColors.outlineVariant,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      StitchButton(
                        key: const Key('intro_next'),
                        label: _page >= 2 ? 'Get started' : 'Continue',
                        icon: Symbols.arrow_forward,
                        background: NordicColors.secondary,
                        radius: 12,
                        onPressed: _next,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        key: const Key('intro_sign_in'),
                        onTap: () => _finish(to: '/login'),
                        child: SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              'Already have an account? Sign In',
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.primary,
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
          ],
        ),
      ),
    );
  }
}

/// One slide: rounded card with illustration + headline and body below.
class _SlideShell extends StatelessWidget {
  const _SlideShell({
    required this.card,
    required this.title,
    required this.body,
    this.background,
  });

  final Widget card;

  /// Painted behind [card], edge to edge (decorative circle / map preview).
  final Widget? background;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Elevated(
          shadows: Tw.sm,
          radius: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 290,
              color: NordicColors.surfaceContainerLow,
              child: Stack(
                children: [
                  ?background,
                  Padding(padding: const EdgeInsets.all(24), child: card),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: NordicText.displayLgMobile.copyWith(
            color: NordicColors.primary,
            letterSpacing: 32 * -0.025,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: NordicText.bodyMd.copyWith(
            color: NordicColors.onSurfaceVariant,
            height: 1.625,
          ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label, this.page);

  final IconData icon;
  final String label;
  final String page;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Elevated(
        shadows: Tw.sm,
        radius: 9999,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: NordicColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MIcon(icon, size: 16, fill: 1, color: NordicColors.secondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: NordicText.labelMd.copyWith(
                  color: NordicColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
      Text(
        page,
        style: NordicText.labelMd.copyWith(
          color: NordicColors.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      MIcon(icon, size: 18, color: NordicColors.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: NordicText.labelSm.copyWith(
            color: NordicColors.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

class _Slide1 extends StatelessWidget {
  const _Slide1();

  @override
  Widget build(BuildContext context) => _SlideShell(
    title: 'Book a ride in seconds.',
    body: 'Travel effortlessly across greater Oslo. See a transparent fare estimate before you confirm every trip.',
    background: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: -48,
          top: -32,
          child: Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              color: Tw.a(NordicColors.surfaceContainerHigh, 0.6),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
    card: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Chip(Symbols.bolt, 'Quick Booking', '01 / 03'),
        const Spacer(),
        Elevated(
          shadows: Tw.sm,
          radius: 12,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: NordicColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Aker Brygge',
                          style: NordicText.labelLg.copyWith(
                            color: NordicColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'EUR 17.44',
                      style: NordicText.currencyDisplay.copyWith(
                        color: NordicColors.primary,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: 16,
                      color: NordicColors.outlineVariant,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: NordicColors.primaryContainer,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Oslo S Jernbane',
                          style: NordicText.labelLg.copyWith(
                            color: NordicColors.onSurface,
                          ),
                        ),
                      ],
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
                      child: Text(
                        'Estimate',
                        style: NordicText.labelSm.copyWith(
                          color: NordicColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        const _Note(
          Symbols.verified,
          'Optimal route • Verified drivers & secure trip',
        ),
      ],
    ),
  );
}

class _Slide2 extends StatelessWidget {
  const _Slide2();

  @override
  Widget build(BuildContext context) => _SlideShell(
    title: 'Track your driver live.',
    body: 'Follow your electric vehicle from request to arrival. Status refreshes every few seconds and you match a one-time safety PIN before stepping inside.',
    background: Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.35,
            child: Image.asset(DesignAssets.mapLive, fit: BoxFit.cover),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  NordicColors.surfaceContainerLow,
                  Tw.a(NordicColors.surfaceContainerLow, 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    card: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Chip(Symbols.near_me, 'Live Status', '02 / 03'),
        const Spacer(),
        Elevated(
          shadows: Tw.sm,
          radius: 12,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLowest,
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
                        decoration: const BoxDecoration(
                          color: NordicColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'MK',
                          style: NordicText.titleSm.copyWith(
                            color: NordicColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Magnus • Polestar 2',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.onSurface,
                              ),
                            ),
                            Row(
                              children: [
                                const MIcon(
                                  Symbols.timer,
                                  size: 14,
                                  lh: 16,
                                  color: NordicColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Arrives in 3 min',
                                  style: NordicText.labelSm.copyWith(
                                    color: NordicColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Safety PIN',
                      style: NordicText.labelSm.copyWith(
                        color: NordicColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '4821',
                      style: NordicText.titleMd.copyWith(
                        color: NordicColors.primary,
                        letterSpacing: 16 * 0.05,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        const _Note(
          Symbols.security,
          'Professional driver • Live GPS route navigation',
        ),
      ],
    ),
  );
}

class _Slide3 extends StatelessWidget {
  const _Slide3();

  @override
  Widget build(BuildContext context) => _SlideShell(
    title: 'Pay your way.',
    body: 'Choose card or paying the driver in cash with flexible, secure payment.',
    background: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: -32,
          bottom: -32,
          child: Blob(
            size: 160,
            color: Tw.a(NordicColors.secondaryContainer, 0.3),
            blur: 40,
          ),
        ),
      ],
    ),
    card: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Chip(
          Symbols.account_balance_wallet,
          'Seamless Payment',
          '03 / 03',
        ),
        const Spacer(),
        Row(
          children: [
            for (final (i, e) in [
              (Symbols.credit_card, 'Card', 'Online', false),
              (Symbols.payments, 'Cash', 'To driver', false),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Elevated(
                  shadows: Tw.sm,
                  radius: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: e.$4
                                ? NordicColors.onTertiaryContainer.withValues(
                                    alpha: 0.15,
                                  )
                                : (i == 0
                                      ? NordicColors.surfaceContainerHigh
                                      : NordicColors.surfaceContainer),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: MIcon(
                              e.$1,
                              size: 18,
                              color: e.$4
                                  ? NordicColors.onTertiaryContainer
                                  : (i == 0
                                        ? NordicColors.primary
                                        : NordicColors.onSurfaceVariant),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.$2,
                          style: NordicText.labelMd.copyWith(
                            color: NordicColors.onSurface,
                          ),
                        ),
                        Text(
                          e.$3,
                          style: NordicText.labelSm.copyWith(
                            color: NordicColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const Spacer(),
        const _Note(
          Symbols.lock,
          'Secure payments • Seamless checkout experience',
        ),
      ],
    ),
  );
}
