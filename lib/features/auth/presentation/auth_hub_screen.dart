import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/validation/validators.dart';
import '../../../shared/stitch.dart';
import '../application/session_controller.dart';

/// Stitch `login_sign_up`: the combined "Log In / New Rider" screen with the brand hero card,
/// provider buttons, the e-mail form and the fleet footnote. It is the alternate entry to the
/// same auth flow as `welcome_screen` + `log_in_screen` + `create_account_*`: reachable at
/// `/auth` (and as the default logged-out entry with `--dart-define=UI_VARIANT=hub`).
///
/// Real: e-mail + password login (POST auth/login); the "New Rider" tab opens the real sign-up
/// flow (`/signup`). Provider buttons, biometrics, language and footer links are intentionally absent.
class AuthHubScreen extends ConsumerStatefulWidget {
  const AuthHubScreen({super.key, this.initialTab = 0});

  /// 0 = Log In, 1 = New Rider.
  final int initialTab;

  @override
  ConsumerState<AuthHubScreen> createState() => _AuthHubScreenState();
}

class _AuthHubScreenState extends ConsumerState<AuthHubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'rider1@example.com');
  final _password = TextEditingController(text: 'Password123!');
  late int _tab = widget.initialTab;
  bool _showPassword = false;
  bool _terms = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_tab == 1) {
      context.push('/signup');
      return;
    }
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(email: _email.text, password: _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNetwork || e.kind == ApiErrorKind.server || e.kind == ApiErrorKind.timeout) {
        await ref
            .read(sessionControllerProvider.notifier)
            .loginAsDemoRider(email: _email.text);
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final notice = session is SessionUnauthenticated ? session.notice : null;
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Elevated(
                        shadows: Tw.sm,
                        radius: 9999,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: NordicColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: NordicColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Oslo Sentrum',
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
                const SizedBox(height: 4),
                Elevated(
                  shadows: Tw.md,
                  radius: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: NordicColors.primaryContainer,
                      padding: const EdgeInsets.all(24),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: -32 - 24,
                            top: -32 - 24,
                            child: Blob(
                              size: 176,
                              color: Tw.a(NordicColors.secondaryFixedDim, 0.2),
                              blur: 40,
                            ),
                          ),
                          Positioned(
                            left: -48 - 24,
                            bottom: -48 - 24,
                            child: Blob(
                              size: 160,
                              color: Tw.a(NordicColors.primary, 0.4),
                              blur: 24,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Elevated(
                                shadows: Tw.sm,
                                radius: 8,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: NordicColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const NordicLogoMark(size: 40),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'NORDIC RIDE',
                                    style: NordicText.labelSm.copyWith(
                                      color: NordicColors.secondaryFixed,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 10 * 0.05,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: NordicColors.secondaryFixed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Zero Emission',
                                    style: NordicText.labelSm.copyWith(
                                      color: NordicColors.primaryFixedDim,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Welcome to Nordic Ride',
                                style: NordicText.displayLgMobile.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 32 * -0.025,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: Text(
                                  'Experience effortless, quiet mobility across Oslo and greater Viken.',
                                  style: NordicText.bodySm.copyWith(
                                    color: NordicColors.primaryFixedDim,
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
                const SizedBox(height: 16),
                Elevated(
                  shadows: Tw.sm,
                  radius: 12,
                  child: Container(
                    key: const Key('hub_tabs'),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: NordicColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        for (final (i, label) in [
                          'Log In',
                          'New Rider',
                        ].indexed)
                          Expanded(
                            child: GestureDetector(
                              key: Key('hub_tab_$i'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _tab = i),
                              child: Elevated(
                                shadows: i == _tab ? Tw.sm : const [],
                                radius: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i == _tab
                                        ? NordicColors.surfaceContainerLowest
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: NordicText.labelLg.copyWith(
                                      color: i == _tab
                                          ? NordicColors.primary
                                          : NordicColors.onSurfaceVariant,
                                      fontWeight: i == _tab
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (notice != null) ...[
                  NordicBanner(message: notice, tone: NordicTone.pending),
                  const SizedBox(height: 16),
                ],
                if (_error != null) ...[
                  NordicBanner(
                    key: const Key('hub_error'),
                    message: _error!,
                    tone: NordicTone.critical,
                  ),
                  const SizedBox(height: 16),
                ],
                _FieldLabel('Email Address'),
                const SizedBox(height: 6),
                _HubField(
                  fieldKey: const Key('hub_email'),
                  controller: _email,
                  hint: 'your.name@domain.no',
                  dot: const _Dot(round: true),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                _FieldLabel(
                  'Password',
                  trailing: GestureDetector(
                    key: const Key('hub_forgot'),
                    onTap: () => context.push('/forgot'),
                    child: Text(
                      'Forgot password?',
                      style: NordicText.labelMd.copyWith(
                        color: NordicColors.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _HubField(
                  fieldKey: const Key('hub_password'),
                  controller: _password,
                  hint: '••••••••••••',
                  dot: const _Dot(round: false),
                  obscure: !_showPassword,
                  validator: Validators.loginPassword,
                  onSubmitted: (_) => _submit(),
                  suffix: GestureDetector(
                    key: const Key('hub_toggle_password'),
                    onTap: () => setState(() => _showPassword = !_showPassword),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: MIcon(
                          _showPassword
                              ? Symbols.visibility_off
                              : Symbols.visibility,
                          size: 20,
                          color: NordicColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        key: const Key('hub_terms'),
                        onTap: () => setState(() => _terms = !_terms),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _terms
                                  ? NordicColors.primary
                                  : NordicColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _terms
                                ? const Center(
                                    child: MIcon(
                                      Symbols.check,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: NordicText.bodySm.copyWith(
                              color: NordicColors.onSurfaceVariant,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => context.push('/terms'),
                                  child: _link('Terms of Service'),
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: GestureDetector(
                                  onTap: () => context.push('/privacy'),
                                  child: _link('Privacy Policy'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StitchButton(
                        key: const Key('hub_submit'),
                        label: _tab == 0
                            ? 'Log In / Sign Up'
                            : 'Create account',
                        icon: Symbols.arrow_forward,
                        loading: _loading,
                        radius: 8,
                        background: NordicColors.primaryContainer,
                        onPressed: (_terms || _tab == 0) ? _submit : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: NordicColors.secondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: MIcon(
                            Symbols.electric_car,
                            size: 20,
                            color: NordicColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '100% Electric Fleet',
                              style: NordicText.labelMd.copyWith(
                                color: NordicColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Clean alpine energy powers every kilometer traveled.',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _link(String text) => Text(
    text,
    style: NordicText.bodySm.copyWith(
      color: NordicColors.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: NordicColors.secondary,
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        text,
        style: NordicText.labelLg.copyWith(
          color: NordicColors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      ?trailing,
    ],
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.round});

  final bool round;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: round ? NordicColors.secondary : NordicColors.primary,
      shape: round ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: round ? null : BorderRadius.circular(2),
    ),
  );
}

class _HubField extends StatelessWidget {
  const _HubField({
    required this.fieldKey,
    required this.controller,
    required this.hint,
    required this.dot,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
    this.suffix,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final Widget dot;
  final bool obscure;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => FormField<String>(
    validator: (_) => validator?.call(controller.text),
    builder: (state) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Elevated(
          shadows: Tw.sm,
          radius: 12,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                dot,
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    key: fieldKey,
                    controller: controller,
                    obscureText: obscure,
                    keyboardType: keyboardType,
                    onChanged: (_) => state.didChange(controller.text),
                    onSubmitted: onSubmitted,
                    style: NordicText.bodyMd.copyWith(
                      color: NordicColors.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      hintText: hint,
                      hintStyle: NordicText.bodyMd.copyWith(
                        color: NordicColors.outline,
                      ),
                    ),
                  ),
                ),
                if (suffix != null) ...[suffix!, const SizedBox(width: 12)],
              ],
            ),
          ),
        ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              state.errorText!,
              style: NordicText.labelSm.copyWith(color: NordicColors.error),
            ),
          ),
      ],
    ),
  );
}
