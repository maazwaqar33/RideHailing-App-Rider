import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../shared/stitch.dart';
import '../../auth/application/session_controller.dart';

/// Stitch `splash_screen`: glow, emblem, "nordic ride", tagline and a thin loader.
/// While visible, the session controller validates any stored token via GET auth/me.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session is SessionRestoreFailed) {
      return _FailedLayout(message: session.message);
    }
    final screenH = MediaQuery.sizeOf(context).height;
    final containerH = screenH * 0.82; // min-h-[82vh]
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Stack(
        children: [
          SizedBox(
            height: containerH,
            width: double.infinity,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // absolute inset-0 flex items-center justify-center opacity-40
                  const _Glow(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 64,
                      horizontal: 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: _TopPill(),
                        ),
                        const _Brand(),
                        const _Loader(failed: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) => Blob(
    size: 288,
    color: NordicColors.secondary.withValues(alpha: 0.4),
    blur: 64,
  );
}

/// Restore failed (timeout / offline): a plain scrollable column, no overlap. Brand block on top,
/// then the friendly error card and the two actions below it. Works at 360x640 and large text.
class _FailedLayout extends ConsumerWidget {
  const _FailedLayout({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, compact ? 16 : 48, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _TopPill(),
                    SizedBox(height: compact ? 24 : 56),
                    SizedBox(
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          const Positioned.fill(
                            child: OverflowBox(
                              minWidth: 0,
                              minHeight: 0,
                              maxWidth: 288,
                              maxHeight: 288,
                              child: _Glow(),
                            ),
                          ),
                          _Brand(compact: compact),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 24 : 48),
                    NordicBanner(
                      message: message,
                      tone: NordicTone.critical,
                      title: 'Could not restore your session',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: StitchButton(
                        key: const Key('splash_retry'),
                        label: 'Try again',
                        onPressed: () => ref
                            .read(sessionControllerProvider.notifier)
                            .restore(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: StitchButton(
                        key: const Key('splash_sign_in_again'),
                        label: 'Sign in again',
                        background: NordicColors.surfaceContainerHigh,
                        foreground: NordicColors.primary,
                        shadow: Tw.sm,
                        onPressed: () => ref
                            .read(sessionControllerProvider.notifier)
                            .signInAgain(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill();

  @override
  Widget build(BuildContext context) => BackdropBlur(
    radius: 9999,
    blur: 12,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Tw.a(NordicColors.surfaceContainerHigh, 0.6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: NordicColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'OSLO • ZERO EMISSION',
            style: NordicText.labelSm.copyWith(
              color: NordicColors.onSurfaceVariant,
              letterSpacing: 10 * 0.1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -12,
            right: -12,
            top: -12,
            bottom: -12,
            child: Blurred(
              sigma: 24,
              child: Container(
                decoration: BoxDecoration(
                  color: Tw.a(NordicColors.secondary, 0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Elevated(
            shadows: Tw.xl2,
            radius: 16,
            child: Container(
              width: compact ? 80 : 96,
              height: compact ? 80 : 96,
              decoration: BoxDecoration(
                color: NordicColors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                DesignAssets.emblem,
                fit: BoxFit.cover,
                semanticLabel: 'nordic ride emblem',
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: compact ? 20 : 32),
      Text(
        'nordic ride',
        style: const TextStyle(
          fontFamily: NordicText.family,
          package: NordicText.package,
          fontSize: 16,
          height: 24 / 16,
          letterSpacing: -0.4,
          color: NordicColors.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Quiet mobility across Oslo',
        style: NordicText.bodySm.copyWith(
          color: NordicColors.onSurfaceVariant,
          letterSpacing: 0,
        ),
      ),
    ],
  );
}

class _Loader extends StatelessWidget {
  const _Loader({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      width: 140,
      height: 3,
      decoration: BoxDecoration(
        color: NordicColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9999),
      ),
      clipBehavior: Clip.antiAlias,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.25, end: 1),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOut,
        builder: (context, v, _) => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: failed ? 0.25 : v,
            child: Container(
              decoration: BoxDecoration(
                color: NordicColors.secondary,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: const [
                  BoxShadow(color: Color(0x99006B5F), blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
