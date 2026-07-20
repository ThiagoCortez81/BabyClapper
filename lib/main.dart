// App entry point and boot sequence: enables immersive fullscreen mode
// (ImmersiveMode), runs the DI bootstrap (core/di/injection_container.dart),
// and mounts the root MaterialApp with RattleScreen wrapped in a
// BlocProvider<RattleBloc>. Also defines `_ImmersiveObserver`, the
// WidgetsBindingObserver that re-asserts immersive mode + wakelock on
// AppLifecycleState.resumed and releases the wakelock once the app leaves
// the foreground (paused/hidden) — `inactive` is a brief, still-visible
// transition (app switcher, incoming call) so the wakelock is deliberately
// left alone there.
import 'dart:async';

import 'package:baby_clapper/core/di/injection_container.dart' as di;
import 'package:baby_clapper/core/system/immersive_mode.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:baby_clapper/features/rattle/presentation/screens/rattle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final immersive = ImmersiveMode();
  await immersive.enable();
  await di.init();
  WidgetsBinding.instance.addObserver(_ImmersiveObserver(immersive));
  runApp(const BabyClapperApp());
}

/// Re-asserts immersive mode + wakelock on resume, and releases the
/// wakelock once the app is no longer foregrounded.
///
/// `inactive` is a brief, still-visible transition (app switcher, incoming
/// call, notification shade) so the wakelock is left alone there; `paused`
/// and `hidden` both mean the app is no longer shown to the user
/// (backgrounded, or occluded in a multi-window/split-screen scenario), so
/// both release the wakelock per the "foregrounded only" spec. `enable()`
/// re-hides the system bars *and* re-enables the wakelock in one call, so
/// resume calls it directly rather than a bars-only step.
class _ImmersiveObserver with WidgetsBindingObserver {
  _ImmersiveObserver(this._immersive);
  final ImmersiveMode _immersive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_immersive.enable());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        unawaited(_immersive.releaseWakelock());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }
}

/// Root widget for the BabyClapper app.
class BabyClapperApp extends StatelessWidget {
  /// Creates the BabyClapper app.
  const BabyClapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BabyClapper',
      debugShowCheckedModeBanner: false,
      home: BlocProvider<RattleBloc>(
        create: (_) => di.sl<RattleBloc>()..add(const RattleInitialized()),
        child: const RattleScreen(),
      ),
    );
  }
}
