import 'dart:async';
import 'dart:developer';

import 'package:baby_clapper/features/rattle/domain/haptic_service.dart';
import 'package:baby_clapper/features/rattle/domain/motion_service.dart';
import 'package:baby_clapper/features/rattle/domain/rattle_math.dart';
import 'package:baby_clapper/features/rattle/domain/sound_service.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_state.dart';
import 'package:bloc/bloc.dart';

/// Coordinates haptic, sound, and motion feedback for the rattle screen.
class RattleBloc extends Bloc<RattleEvent, RattleState> {
  /// Creates a [RattleBloc] wired to the given feedback services.
  RattleBloc({
    required HapticService haptic,
    required SoundService sound,
    required MotionService motion,
  }) : // Kept as plain assignments (not `this._haptic`, etc.) because the
       // public constructor parameters (`haptic`, `sound`, `motion`) must
       // keep those exact names for other tasks to depend on, while the
       // backing fields stay private (`_haptic`, `_sound`, `_motion`).
       // ignore: prefer_initializing_formals
       _haptic = haptic,
       // Same rationale as above: field name differs from the required
       // public parameter name.
       // ignore: prefer_initializing_formals
       _sound = sound,
       // Same rationale as above: field name differs from the required
       // public parameter name.
       // ignore: prefer_initializing_formals
       _motion = motion,
       super(const RattleState()) {
    // Wired synchronously (not inside the async `_onInitialized` handler)
    // so the subscription is guaranteed to exist before any shake can be
    // missed: `add()` defers event processing to a microtask, so waiting
    // for RattleInitialized to be handled would let shakes emitted
    // immediately after construction race past an unattached listener.
    _shakeSub = _motion.shakes.listen((_) => add(const RattleShaken()));
    on<RattleInitialized>(_onInitialized);
    on<SwipeTick>(_onSwipeTick);
    on<RattleShaken>(_onShaken);
  }

  final HapticService _haptic;
  final SoundService _sound;
  final MotionService _motion;
  StreamSubscription<void>? _shakeSub;

  Future<void> _onInitialized(
    RattleInitialized event,
    Emitter<RattleState> emit,
  ) async {
    emit(state.copyWith(ready: true));
  }

  Future<void> _onSwipeTick(SwipeTick event, Emitter<RattleState> emit) async {
    final intensity = swipeIntensity(event.velocity);
    final bead = beadPlayback(event.velocity);
    await Future.wait([
      _guard(_haptic.tick(intensity)),
      _guard(_sound.playBead(rate: bead.rate, volume: bead.volume)),
    ]);
  }

  Future<void> _onShaken(RattleShaken event, Emitter<RattleState> emit) async {
    await Future.wait([
      _guard(_haptic.burst()),
      _guard(_sound.playRattle()),
    ]);
  }

  /// Runs a feedback future in isolation: a failure in one channel is logged
  /// and swallowed so it can never block or crash the other channel.
  Future<void> _guard(Future<void> action) async {
    try {
      await action;
      // Intentionally broad: any failure (Exception or Error) in one
      // feedback channel must be swallowed so it can never crash or block
      // the other channel.
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      log(
        'feedback failed',
        name: 'RattleBloc',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    await _shakeSub?.cancel();
    return super.close();
  }
}
