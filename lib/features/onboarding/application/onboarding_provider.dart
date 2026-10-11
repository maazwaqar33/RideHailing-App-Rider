import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

const _kOnboardingSeen = 'flag.onboarding_seen';

/// Non-secret first-run flag kept in SharedPreferences.
class OnboardingSeenController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kOnboardingSeen) ?? false;

  Future<void> markSeen() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_kOnboardingSeen, true);
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingSeenController, bool>(
  OnboardingSeenController.new,
);
