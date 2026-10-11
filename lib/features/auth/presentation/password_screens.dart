import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/validation/validators.dart';
import '../../../shared/nav_scaffold.dart';
import '../../../shared/stitch.dart';
import '../../../shared/stitch_fields.dart';

/// Forgot password: POST auth/password/forgot (always 202, never reveals whether the email exists).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _error = null;
      _success = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .forgotPassword(_email.text);
      if (mounted) setState(() => _success = message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Column(
        children: [
          StitchBackHeader(
            title: 'Forgot password',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/login'),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
                  Text(
                    'Reset your password',
                    style: NordicText.headlineMd.copyWith(
                      color: NordicColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your account email. If it exists, we'll send a reset link with a token.",
                    style: NordicText.bodyMd.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    NordicBanner(message: _error!, tone: NordicTone.critical),
                    const SizedBox(height: 12),
                  ],
                  if (_success != null) ...[
                    NordicBanner(
                      key: const Key('forgot_success'),
                      message: _success!,
                      tone: NordicTone.success,
                    ),
                    const SizedBox(height: 12),
                  ],
                  StitchTextField(
                    key: const Key('forgot_email'),
                    label: 'Email address',
                    controller: _email,
                    icon: Symbols.mail,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  StitchButton(
                    key: const Key('forgot_submit'),
                    label: 'Send reset link',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  StitchButton(
                    key: const Key('forgot_have_token'),
                    label: 'I have a reset token',
                    background: NordicColors.surfaceContainer,
                    foreground: NordicColors.primary,
                    shadow: const [],
                    onPressed: () => context.push(
                      '/reset?email=${Uri.encodeQueryComponent(_email.text.trim())}',
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

/// Reset password: POST auth/password/reset with the token from the email link.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.email, this.token});

  final String? email;
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email ?? '');
  late final _token = TextEditingController(text: widget.token ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _error = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(
            email: _email.text,
            token: _token.text,
            password: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Please log in.')),
      );
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = {
          for (final en in e.fieldErrors.entries)
            if (en.value.isNotEmpty) en.key: en.value.first,
        };
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Column(
        children: [
          StitchBackHeader(
            title: 'Set a new password',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/login'),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
                  Text(
                    'Choose a new password',
                    style: NordicText.headlineMd.copyWith(
                      color: NordicColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste the token from the reset email. All other signed-in devices will be signed out.',
                    style: NordicText.bodyMd.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    NordicBanner(
                      key: const Key('reset_error'),
                      message: _error!,
                      tone: NordicTone.critical,
                    ),
                    const SizedBox(height: 12),
                  ],
                  StitchTextField(
                    key: const Key('reset_email'),
                    label: 'Email address',
                    controller: _email,
                    icon: Symbols.mail,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    serverError: _fieldErrors['email'],
                  ),
                  const SizedBox(height: 16),
                  StitchTextField(
                    key: const Key('reset_token'),
                    label: 'Reset token',
                    controller: _token,
                    icon: Symbols.key,
                    validator: Validators.resetToken,
                    serverError: _fieldErrors['token'],
                  ),
                  const SizedBox(height: 16),
                  StitchTextField(
                    key: const Key('reset_password'),
                    label: 'New password',
                    controller: _password,
                    icon: Symbols.lock,
                    obscure: true,
                    validator: Validators.newPassword,
                    serverError: _fieldErrors['password'],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'At least 10 characters with upper and lower case letters and a number.',
                      style: NordicText.labelSm.copyWith(
                        color: NordicColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StitchTextField(
                    key: const Key('reset_confirm'),
                    label: 'Confirm new password',
                    controller: _confirm,
                    icon: Symbols.lock,
                    obscure: true,
                    validator: (v) =>
                        Validators.confirmPassword(v, _password.text),
                  ),
                  const SizedBox(height: 24),
                  StitchButton(
                    key: const Key('reset_submit'),
                    label: 'Reset password',
                    loading: _loading,
                    onPressed: _submit,
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

/// Placeholder legal text (POC). Real documents must be supplied by legal.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  factory LegalScreen.terms() => const LegalScreen(
    title: 'Terms of Service',
    sections: [
      (
        'Proof of concept',
        'Nordic Ride is a proof of concept. These terms are placeholder text and are not legally binding.',
      ),
      (
        'Using the app',
        'You can request rides, follow their status and review past trips. Fares shown are estimates calculated by the Nordic Mobility backend.',
      ),
      (
        'Payments',
        'Payments are securely processed for each trip according to standard terms.',
      ),
      (
        'Accounts',
        'Keep your password private. You can log out at any time from your profile.',
      ),
    ],
  );

  factory LegalScreen.privacy() => const LegalScreen(
    title: 'Privacy Policy',
    sections: [
      (
        'Proof of concept',
        'This policy is placeholder text for the Nordic Ride proof of concept.',
      ),
      (
        'Data we process',
        'Your name, email, optional phone number, ride requests and ride history are stored by the Nordic Mobility backend.',
      ),
      (
        'Location',
        'Your device location is used on the device to suggest a pickup point. It is not uploaded unless you book a ride from it.',
      ),
      (
        'Stored on your device',
        'Your session token is kept in the secure keystore. Saved places, ratings, tips and reports are kept locally on this device only.',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NordicColors.surface,
      body: Column(
        children: [
          StitchBackHeader(
            title: title,
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/login'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                const NordicBanner(
                  message: 'Placeholder legal text for a proof of concept.',
                  tone: NordicTone.pending,
                ),
                const SizedBox(height: 16),
                for (final s in sections) ...[
                  Text(
                    s.$1,
                    style: NordicText.titleMd.copyWith(
                      color: NordicColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.$2,
                    style: NordicText.bodyMd.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
