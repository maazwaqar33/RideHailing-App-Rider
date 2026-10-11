import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../shared/stitch.dart';
import '../application/session_controller.dart';

/// Stitch `welcome_screen`.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => context.push('/terms');
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => context.push('/privacy');

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final notice = session is SessionUnauthenticated ? session.notice : null;
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top utility bar
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Elevated(
                      shadows: Tw.sm,
                      radius: 9999,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                              Symbols.eco,
                              size: 16,
                              fill: 1,
                              color: NordicColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '100% ELEKTRISK',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.onSurfaceVariant,
                                letterSpacing: 10 * 0.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (notice != null) ...[
                NordicBanner(message: notice, tone: NordicTone.pending),
                const SizedBox(height: 12),
              ],
              _HeroCard(),
              const SizedBox(height: 24),
              // CTAs
              StitchButton(
                key: const Key('welcome_create_account'),
                label: 'Create account',
                icon: Symbols.arrow_forward,
                onPressed: () => context.push('/signup'),
                background: NordicColors.primaryContainer,
                radius: 8,
              ),
              const SizedBox(height: 8),
              StitchButton(
                key: const Key('welcome_login'),
                label: 'Log in',
                onPressed: () => context.push('/login'),
                background: NordicColors.surfaceContainerHigh,
                foreground: NordicColors.primary,
                radius: 8,
                shadow: Tw.sm,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        style: NordicText.bodySm.copyWith(
                          color: NordicColors.outline,
                          height: 1.625,
                        ),
                        children: [
                          const TextSpan(
                            text: "By continuing, you agree to Nordic Ride's ",
                          ),
                          TextSpan(
                            text: 'Terms of Service',
                            recognizer: _terms,
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.onSurfaceVariant,
                              decoration: TextDecoration.underline,
                              height: 1.625,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            recognizer: _privacy,
                            style: NordicText.labelMd.copyWith(
                              color: NordicColors.onSurfaceVariant,
                              decoration: TextDecoration.underline,
                              height: 1.625,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 21,
                      child: Center(
                        child: Text(
                          'Designed with care in Norway • Nordic Mobility AS',
                          style: NordicText.labelSm.copyWith(
                            color: NordicColors.outline,
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
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Elevated(
      shadows: Tw.sm,
      radius: 12,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NordicColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        // The image is 176 px high, then mb-space-md (16) and the brand block has -mt-12 (-48):
        // the brand starts 144 px below the card content top and overlaps the image.
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 176,
              child: Container(
                decoration: BoxDecoration(
                  color: NordicColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(DesignAssets.skyline, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Tw.a(NordicColors.primary, 0.8),
                            Tw.a(NordicColors.primary, 0.2),
                            Tw.a(NordicColors.primary, 0),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MIcon(
                              Symbols.location_on,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Oslo • Viken • Gardermoen',
                              style: NordicText.labelMd.copyWith(
                                color: Colors.white,
                                letterSpacing: 12 * 0.025,
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
            Column(
              children: [
                const SizedBox(height: 144),
                Elevated(
                  shadows: Tw.md,
                  radius: 12,
                  child: Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        DesignAssets.emblem,
                        fit: BoxFit.contain,
                        semanticLabel: 'Nordic Ride Logo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nordic Ride',
                      style: NordicText.headlineSm.copyWith(
                        color: NordicColors.primary,
                        letterSpacing: 20 * -0.025,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: NordicColors.secondaryFixedDim,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your ride in Oslo',
                  textAlign: TextAlign.center,
                  style: NordicText.headlineLg.copyWith(
                    color: NordicColors.primary,
                    letterSpacing: 28 * -0.025,
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    'Effortless, sustainable electric mobility across Oslo and Viken.',
                    textAlign: TextAlign.center,
                    style: NordicText.bodyMd.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _chip(
                        Symbols.bolt,
                        NordicColors.secondary,
                        'Zero Emission',
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        Symbols.schedule,
                        NordicColors.primary,
                        'Avg 3 min pickup',
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

  Widget _chip(IconData icon, Color color, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: NordicColors.surfaceContainer,
      borderRadius: BorderRadius.circular(9999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MIcon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: NordicText.labelSm.copyWith(color: NordicColors.onSurface),
        ),
      ],
    ),
  );
}
