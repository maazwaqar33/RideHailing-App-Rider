import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/validation/validators.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../application/session_controller.dart';
import '../domain/auth_models.dart';

/// Stitch `create_account_step_1/3` and `_3/3`. Sign-up is real (POST auth/register). Stitch's
/// step 2 (SMS verification) is intentionally absent: there is no OTP service, so the flow has two
/// steps and the phone number is an optional field on step 1. BankID/Vipps and biometric rows,
/// and the unbacked telemetry/marketing consents, are also absent.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, this.initialStep = 1});

  final int initialStep;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _step1Key = GlobalKey<FormState>();

  late int _step = widget.initialStep;
  bool _terms = false;
  bool _submitted = false;
  bool _passwordTouched = false;
  bool _loading = false;
  String? _formError;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _password, _phone]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      context.canPop() ? context.pop() : context.go('/welcome');
    }
  }

  void _next() {
    setState(() {
      _formError = null;
      _passwordTouched = true;
    });
    if (_step == 1 && _step1Key.currentState!.validate()) {
      setState(() => _step = 2);
    }
  }

  Future<void> _create() async {
    if (_loading) return;
    setState(() {
      _submitted = true;
      _formError = null;
      _fieldErrors = {};
    });
    if (!_terms) return;
    setState(() => _loading = true);
    final (first, last) = Validators.splitName(_name.text);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .register(
            RegisterRequest(
              firstName: first,
              lastName: last,
              email: _email.text,
              password: _password.text,
              phone: _phone.text,
            ),
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.kind == ApiErrorKind.validation && e.fieldErrors.isNotEmpty) {
          _fieldErrors = {
            for (final entry in e.fieldErrors.entries)
              if (entry.value.isNotEmpty) entry.key: entry.value.first,
          };
          if (_fieldErrors.keys.any(
            (k) => const [
              'first_name',
              'last_name',
              'email',
              'password',
              'phone',
            ].contains(k),
          )) {
            _step = 1;
          }
        }
        _formError = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                64 + MediaQuery.paddingOf(context).top,
                16,
                32,
              ),
              child: _step == 1 ? _stepOne() : _stepTwo(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StitchBackHeader(
              title: 'Multi Step Signup',
              onBack: _back,
              backKey: const Key('signup_back'),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ step 1
  Widget _stepOne() {
    final pw = _password.text;
    final rules = Validators.passwordRules(pw);
    final met = rules.where((r) => r.satisfied).length;
    final passwordError =
        _fieldErrors['password'] ??
        (_passwordTouched && pw.isNotEmpty ? Validators.newPassword(pw) : null);
    final hasPwError = passwordError != null;
    final segments = pw.isEmpty
        ? 0
        : (met == 3 ? (pw.length >= 14 ? 4 : 3) : met);
    final strengthLabel = pw.isEmpty
        ? ''
        : (met == 3
              ? (segments == 4 ? 'Strong' : 'Good')
              : (met == 2 ? 'Medium' : 'Weak'));
    final strengthColor = met == 3
        ? NordicColors.secondary
        : NordicColors.onTertiaryContainer;
    final nameOk = Validators.fullName(_name.text) == null;
    final emailOk = Validators.email(_email.text) == null;

    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'OSLO MOBILITY ID',
                  style: NordicText.labelMd.copyWith(
                    color: NordicColors.secondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 12 * 0.05,
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
                  child: Text(
                    'Step 1 of 2',
                    style: NordicText.labelMd.copyWith(
                      color: NordicColors.primaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ProgressBar(
            fraction: 0.5,
            color: const Color(0xFF14B8A6),
            shadow: Tw.sm,
            margin: 4,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Tw.a(NordicColors.secondary, 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: MIcon(
                            Symbols.electric_car,
                            size: 22,
                            color: NordicColors.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zero-emission journeys',
                              style: NordicText.titleSm.copyWith(
                                color: NordicColors.onSurface,
                              ),
                            ),
                            Text(
                              '100% electric fleet across Oslo',
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
                const SizedBox(width: 8),
                Container(
                  width: 43,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: NordicColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '100% EL',
                    style: NordicText.labelSm.copyWith(
                      color: NordicColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SignupField(
            key: const Key('signup_name'),
            label: 'Full Name',
            icon: Symbols.person,
            controller: _name,
            hint: 'Enter legal name',
            ok: nameOk,
            okLabel: 'Looks good',
            okLabelIcon: Symbols.verified,
            validator: Validators.fullName,
            serverError:
                _fieldErrors['first_name'] ?? _fieldErrors['last_name'],
          ),
          const SizedBox(height: 16),
          _SignupField(
            key: const Key('signup_email'),
            label: 'Email address',
            icon: Symbols.mail,
            controller: _email,
            hint: 'your.name@domain.no',
            keyboardType: TextInputType.emailAddress,
            ok: emailOk && _fieldErrors['email'] == null,
            okLabel: 'Valid format',
            okLabelIcon: Symbols.check_circle,
            validator: Validators.email,
            serverError: _fieldErrors['email'],
          ),
          const SizedBox(height: 16),
          _SignupField(
            key: const Key('signup_phone'),
            label: 'Phone number (optional)',
            icon: Symbols.call,
            controller: _phone,
            hint: '+47 941 23 891',
            keyboardType: TextInputType.phone,
            validator: Validators.optionalPhone,
            serverError: _fieldErrors['phone'],
          ),
          const SizedBox(height: 16),
          _SignupField(
            key: const Key('signup_password'),
            label: 'Password',
            icon: Symbols.lock,
            controller: _password,
            hint: 'Create safe password',
            obscureByDefault: true,
            hasError: hasPwError,
            errorLabel: 'Action required',
            ok: pw.isNotEmpty && !hasPwError,
            okLabel: 'Strong enough',
            okLabelIcon: Symbols.check_circle,
            validator: Validators.newPassword,
            serverError: _fieldErrors['password'],
            showInlineError: false,
            toggleKey: const Key('signup_password_toggle'),
          ),
          if (hasPwError) ...[
            const SizedBox(height: 4),
            Container(
              key: const Key('password_error_callout'),
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NordicColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: MIcon(
                      Symbols.error,
                      size: 18,
                      color: NordicColors.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      passwordError,
                      style: NordicText.labelSm.copyWith(
                        color: NordicColors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8 + 4),
          Container(
            key: const Key('password_strength'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NordicColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Security strength',
                      style: NordicText.labelMd.copyWith(
                        color: NordicColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      strengthLabel.toUpperCase(),
                      style: NordicText.labelMd.copyWith(
                        color: strengthColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 12 * 0.025,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: i < segments
                                ? strengthColor
                                : NordicColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < rules.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _RuleRow(
                          label: rules[i].label,
                          met: rules[i].satisfied,
                          showMissing: pw.isNotEmpty,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            NordicBanner(
              key: const Key('signup_error'),
              message: _formError!,
              tone: NordicTone.critical,
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 16 + 8),
            child: Column(
              children: [
                StitchButton(
                  key: const Key('signup_continue'),
                  label: 'Continue',
                  icon: Symbols.arrow_forward,
                  onPressed: _next,
                  radius: 8,
                ),
                const SizedBox(height: 16),
                _LoginLink(onTap: () => context.go('/login')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ step 2
  Widget _stepTwo() {
    Widget consent({
      required Key key,
      required bool value,
      required ValueChanged<bool> onChanged,
      required Widget title,
      required Widget sub,
      bool compact = false,
    }) {
      return GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NordicColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08 << 24 | 0x0F2A4A),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value
                        ? NordicColors.primary
                        : NordicColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // The Stitch screenshot shows the checked box as a solid navy square (its check glyph is hidden).
                  child: null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, sub],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final titleStyle = NordicText.titleSm.copyWith(
      color: NordicColors.onSurface,
      fontSize: 14,
      height: 1.25,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const MIcon(
                        Symbols.verified_user,
                        size: 16,
                        color: NordicColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'STEP 2 OF 2',
                        style: NordicText.labelMd.copyWith(
                          color: NordicColors.secondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 12 * 0.05,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'ALMOST READY',
                    style: NordicText.labelMd.copyWith(
                      color: Tw.a(NordicColors.onSurfaceVariant, 0.8),
                      letterSpacing: 12 * 0.05,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const _ProgressBar(
                fraction: 1,
                color: NordicColors.secondaryFixedDim,
                glow: Color(0x994FDBC8),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // headline-lg-mobile is not defined in the design's Tailwind config -> inherits 16/24 regular.
              Text(
                'Preferences & Terms',
                style: const TextStyle(
                  fontFamily: NordicText.family,
                  package: NordicText.package,
                  fontSize: 16,
                  height: 24 / 16,
                  letterSpacing: -0.4,
                  color: NordicColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review how we use your location and accept the terms to get rolling across Oslo.',
                style: NordicText.bodySm.copyWith(
                  color: NordicColors.onSurfaceVariant,
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
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0F2A4A),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Tw.a(NordicColors.secondary, 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: MIcon(
                      Symbols.near_me,
                      size: 20,
                      color: NordicColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Location transparency',
                            style: NordicText.titleSm.copyWith(
                              color: NordicColors.onSurface,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: NordicColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'GPS',
                              style: const TextStyle(
                                fontFamily: NordicText.family,
                                package: NordicText.package,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: NordicColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We use precise location to pinpoint your Oslo pickup spot, calculate exact upfront fares, and guide your driver directly to your doorstep.',
                        style: NordicText.bodySm.copyWith(
                          color: NordicColors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.625,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'AGREEMENTS & CONSENTS',
                    style: NordicText.labelMd.copyWith(
                      color: NordicColors.onSurfaceVariant,
                      letterSpacing: 12 * 0.05,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                consent(
                  key: const Key('signup_terms'),
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v),
                  title: Text.rich(
                    TextSpan(
                      style: titleStyle,
                      children: [
                        const TextSpan(text: 'I accept the '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => context.push('/terms'),
                            child: Text(
                              'Terms of Service',
                              style: titleStyle.copyWith(
                                color: NordicColors.secondary,
                                decoration: TextDecoration.underline,
                                decorationColor: Tw.a(
                                  NordicColors.secondary,
                                  0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' & '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => context.push('/privacy'),
                            child: Text(
                              'Privacy Policy',
                              style: titleStyle.copyWith(
                                color: NordicColors.secondary,
                                decoration: TextDecoration.underline,
                                decorationColor: Tw.a(
                                  NordicColors.secondary,
                                  0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  sub: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _submitted && !_terms
                          ? 'You must accept the Terms and Privacy Policy to continue.'
                          : 'Required to establish account',
                      style: NordicText.labelSm.copyWith(
                        color: _submitted && !_terms
                            ? NordicColors.error
                            : NordicColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            NordicBanner(
              key: const Key('signup_error'),
              message: _formError!,
              tone: NordicTone.critical,
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 8 + 8, bottom: 24),
            child: Column(
              children: [
                StitchButton(
                  key: const Key('signup_create'),
                  label: 'Create account',
                  icon: Symbols.arrow_forward,
                  loading: _loading,
                  onPressed: _create,
                  radius: 12,
                  shadow: const [
                    BoxShadow(
                      color: Color(0x2E00152F),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MIcon(
                      Symbols.lock,
                      size: 14,
                      color: NordicColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Your details are sent to Nordic Mobility to create the account',
                      style: NordicText.labelSm.copyWith(
                        color: NordicColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.fraction,
    required this.color,
    this.shadow = const [],
    this.margin = 0,
    this.glow,
  });

  final double fraction;
  final Color color;
  final List<BoxShadow> shadow;
  final double margin;
  final Color? glow;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: margin),
    child: Container(
      height: 6,
      decoration: BoxDecoration(
        color: NordicColors.surfaceContainer,
        borderRadius: BorderRadius.circular(9999),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9999),
              boxShadow: [
                if (glow != null) BoxShadow(color: glow!, blurRadius: 12),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.label,
    required this.met,
    required this.showMissing,
  });

  final String label;
  final bool met;
  final bool showMissing;

  @override
  Widget build(BuildContext context) {
    final missing = !met && showMissing;
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: met
                ? Tw.a(NordicColors.secondary, 0.2)
                : (missing
                      ? NordicColors.error
                      : NordicColors.surfaceContainerHighest),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: MIcon(
              met ? Symbols.check : Symbols.close,
              size: 12,
              weight: 700,
              color: met
                  ? NordicColors.secondary
                  : (missing ? Colors.white : NordicColors.outline),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: NordicText.labelSm.copyWith(
              color: missing
                  ? NordicColors.error
                  : NordicColors.onSurfaceVariant,
              fontWeight: missing ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginLink extends StatelessWidget {
  const _LoginLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: NordicText.bodySm.copyWith(
            color: NordicColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onTap,
          child: Text(
            'Log in',
            style: NordicText.titleSm.copyWith(
              color: NordicColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Sign-up field: label-lg row with optional status, 56 px white field with leading Symbol and
/// optional status circle. [hasError] switches to the red error variant.
class _SignupField extends StatefulWidget {
  const _SignupField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.ok = false,
    this.okLabel,
    this.okLabelIcon,
    this.hasError = false,
    this.errorLabel,
    this.obscureByDefault = false,
    this.validator,
    this.serverError,
    this.showInlineError = true,
    this.toggleKey,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool ok;
  final String? okLabel;
  final IconData? okLabelIcon;
  final bool hasError;
  final String? errorLabel;
  final bool obscureByDefault;
  final FormFieldValidator<String>? validator;
  final String? serverError;
  final bool showInlineError;
  final Key? toggleKey;

  @override
  State<_SignupField> createState() => _SignupFieldState();
}

class _SignupFieldState extends State<_SignupField> {
  late bool _hidden = widget.obscureByDefault;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.controller.text),
      builder: (state) {
        final err =
            widget.hasError ||
            widget.serverError != null ||
            (widget.showInlineError && state.hasError);
        final showOk = widget.ok && !err && widget.controller.text.isNotEmpty;
        final textColor = err && !widget.showInlineError
            ? NordicColors.error
            : NordicColors.onSurface;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label,
                  style: NordicText.labelLg.copyWith(
                    color: NordicColors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (err && widget.errorLabel != null)
                  Row(
                    children: [
                      const MIcon(
                        Symbols.warning,
                        size: 14,
                        color: NordicColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        widget.errorLabel!,
                        style: NordicText.labelSm.copyWith(
                          color: NordicColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else if (showOk && widget.okLabel != null)
                  Row(
                    children: [
                      MIcon(
                        widget.okLabelIcon ?? Symbols.check_circle,
                        size: 14,
                        color: NordicColors.secondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        widget.okLabel!,
                        style: NordicText.labelSm.copyWith(
                          color: NordicColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Elevated(
              shadows: _focus.hasFocus ? Tw.md : Tw.sm,
              radius: 12,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: widget.hasError
                      ? Tw.a(NordicColors.errorContainer, 0.3)
                      : NordicColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      (widget.serverError != null ||
                          (widget.showInlineError && state.hasError))
                      ? Border.all(color: NordicColors.error, width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: MIcon(
                        widget.icon,
                        size: 20,
                        color: widget.hasError
                            ? NordicColors.error
                            : NordicColors.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        obscureText: _hidden,
                        keyboardType: widget.keyboardType,
                        style: NordicText.bodyMd.copyWith(color: textColor),
                        cursorColor: NordicColors.secondary,
                        onChanged: (_) {
                          if (state.hasError) state.validate();
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: widget.hint,
                          hintStyle: NordicText.bodyMd.copyWith(
                            color: NordicColors.outline,
                          ),
                          contentPadding: EdgeInsets.only(
                            left: 12,
                            right: widget.obscureByDefault ? 8 : 12,
                          ),
                        ),
                      ),
                    ),
                    if (widget.obscureByDefault)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(
                          children: [
                            GestureDetector(
                              key: widget.toggleKey,
                              onTap: () => setState(() => _hidden = !_hidden),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: MIcon(
                                  _hidden
                                      ? Symbols.visibility
                                      : Symbols.visibility_off,
                                  size: 20,
                                  color: widget.hasError
                                      ? Tw.a(NordicColors.error, 0.8)
                                      : NordicColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (widget.hasError)
                              Elevated(
                                shadows: Tw.sm,
                                circle: true,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: NordicColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: MIcon(
                                      Symbols.priority_high,
                                      size: 16,
                                      weight: 700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            else if (showOk)
                              _okCircle(),
                          ],
                        ),
                      )
                    else if (showOk)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _okCircle(),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.showInlineError &&
                (widget.serverError != null || state.hasError))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  widget.serverError ?? state.errorText!,
                  style: NordicText.labelMd.copyWith(
                    color: NordicColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _okCircle() => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Tw.a(NordicColors.secondary, 0.15),
      shape: BoxShape.circle,
    ),
    child: const Center(
      child: MIcon(
        Symbols.check,
        size: 16,
        weight: 700,
        color: NordicColors.secondary,
      ),
    ),
  );
}
