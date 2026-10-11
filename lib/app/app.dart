import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import '../features/auth/application/session_controller.dart';
import 'app_router.dart';

class RiderApp extends ConsumerStatefulWidget {
  const RiderApp({super.key, this.restoreSession = true});

  /// Tests that drive the session by hand disable the automatic restore.
  final bool restoreSession;

  @override
  ConsumerState<RiderApp> createState() => _RiderAppState();
}

class _RiderAppState extends ConsumerState<RiderApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.restoreSession) {
      Future.microtask(
        () => ref.read(sessionControllerProvider.notifier).restore(),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the foreground: validate / rotate the JWT before the rider taps anything.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionControllerProvider.notifier).onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nordic Ride',
      debugShowCheckedModeBanner: false,
      theme: NordicTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
