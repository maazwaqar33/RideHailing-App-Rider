import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/validation/validators.dart';
import '../../../shared/stitch.dart';
import '../../../shared/stitch_fields.dart';
import '../application/session_controller.dart';
import '../data/remembered_user.dart';

/// Stitch `log_in_screen`. Email + password sign-in is real (POST auth/login). Vipps, Google,
/// Apple and biometric sign-in are intentionally absent (the backend has no provider endpoints).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _formError;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _formError = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(email: _email.text, password: _password.text);
      // The router redirects to /home once the session is authenticated.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.kind == ApiErrorKind.validation) {
          _fieldErrors = {
            for (final entry in e.fieldErrors.entries)
              if (entry.value.isNotEmpty) entry.key: entry.value.first,
          };
          if (_fieldErrors.isEmpty) _formError = e.message;
        } else {
          _formError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final notice = session is SessionUnauthenticated ? session.notice : null;
    final remembered = ref.watch(rememberedUserProvider);

    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _HeroCard(),
              const SizedBox(height: 24),
              if (notice != null) ...[
                NordicBanner(message: notice, tone: NordicTone.pending),
                const SizedBox(height: 16),
              ],
              if (_formError != null) ...[
                NordicBanner(
                  key: const Key('login_error'),
                  message: _formError!,
                  tone: NordicTone.critical,
                ),
                const SizedBox(height: 16),
              ],
              if (remembered != null) ...[
                _ReturningRiderCard(
                  user: remembered,
                  onUnlock: () =>
                      setState(() => _email.text = remembered.email),
                ),
                const SizedBox(height: 16),
              ],
              StitchTextField(
                key: const Key('login_email'),
                label: 'Email address',
                controller: _email,
                icon: Symbols.mail,
                hint: 'navn@domene.no',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                serverError: _fieldErrors['email'],
              ),
              const SizedBox(height: 16),
              StitchTextField(
                key: const Key('login_password'),
                label: 'Password',
                controller: _password,
                icon: Symbols.lock,
                hint: '••••••••',
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.loginPassword,
                serverError: _fieldErrors['password'],
                onSubmitted: (_) => _submit(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    key: const Key('login_forgot'),
                    onTap: () => context.push('/forgot'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Forgot password?',
                        style: NordicText.labelLg.copyWith(
                          color: NordicColors.primaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4 + 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StitchButton(
                        key: const Key('login_submit'),
                        label: 'Log in',
                        icon: Symbols.arrow_forward,
                        loading: _loading,
                        onPressed: _submit,
                        background: NordicColors.primaryContainer,
                        radius: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      style: NordicText.bodySm.copyWith(
                        color: NordicColors.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'New to Nordic Ride? '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            key: const Key('login_to_signup'),
                            onTap: () => context.push('/signup'),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Create account',
                                    style: NordicText.titleSm.copyWith(
                                      color: NordicColors.primaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const MIcon(
                                    Symbols.open_in_new,
                                    size: 16,
                                    color: NordicColors.primaryContainer,
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: NordicColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -32 - 24,
              top: -32 - 24,
              child: Blob(
                size: 128,
                color: Tw.a(NordicColors.secondaryFixed, 0.2),
                blur: 40,
              ),
            ),
            Positioned(
              left: -24 - 24,
              bottom: -24 - 24,
              child: Blob(
                size: 112,
                color: Tw.a(NordicColors.surfaceVariant, 0.4),
                blur: 24,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Elevated(
                            shadows: Tw.sm,
                            radius: 8,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: NordicColors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: MIcon(
                                  Symbols.electric_bolt,
                                  size: 24,
                                  color: NordicColors.secondaryFixed,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NORDIC RIDE',
                                  style: NordicText.labelMd.copyWith(
                                    color: NordicColors.onSurfaceVariant,
                                    letterSpacing: 12 * 0.05,
                                  ),
                                ),
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
                                    Flexible(
                                      child: Text(
                                        'Oslo • 100% Zero Emission',
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Elevated(
                      shadows: Tw.sm,
                      radius: 9999,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: NordicColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MIcon(
                              Symbols.shield,
                              size: 16,
                              fill: 1,
                              color: NordicColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Secure sign-in',
                              style: NordicText.labelSm.copyWith(
                                color: NordicColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome back',
                  style: NordicText.displayLgMobile.copyWith(
                    color: NordicColors.onSurface,
                    letterSpacing: 32 * -0.025,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to book silent, sustainable fjord-class transit.',
                  style: NordicText.bodySm.copyWith(
                    color: NordicColors.onSurfaceVariant,
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

/// Returning-rider pill (last signed-in name and email on this device) with a "Use" button that
/// pre-fills the e-mail field.
class _ReturningRiderCard extends StatelessWidget {
  const _ReturningRiderCard({required this.user, required this.onUnlock});

  final RememberedUser user;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) => Elevated(
    shadows: Tw.sm,
    radius: 12,
    child: Container(
      key: const Key('returning_rider'),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: NordicColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: NordicColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.initials,
                        style: NordicText.titleSm.copyWith(
                          color: NordicColors.primaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: NordicColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: MIcon(
                            Symbols.bolt,
                            size: 10,
                            fill: 1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NordicText.titleSm.copyWith(
                          color: NordicColors.onSurface,
                        ),
                      ),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NordicText.labelSm.copyWith(
                          color: NordicColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            key: const Key('login_unlock'),
            onTap: onUnlock,
            child: Elevated(
              shadows: Tw.sm,
              radius: 8,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: NordicColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MIcon(
                      Symbols.person,
                      size: 20,
                      color: NordicColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Use',
                      style: NordicText.labelMd.copyWith(
                        color: NordicColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
