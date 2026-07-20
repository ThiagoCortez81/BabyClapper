import 'package:equatable/equatable.dart';

/// Base type for all events handled by `RattleBloc`.
sealed class RattleEvent extends Equatable {
  const RattleEvent();

  @override
  List<Object?> get props => const [];
}

/// Fired once at startup: wires the shake subscription.
class RattleInitialized extends RattleEvent {
  /// Creates a [RattleInitialized] event.
  const RattleInitialized();
}

/// A throttled swipe sample; [velocity] is px/ms.
class SwipeTick extends RattleEvent {
  /// Creates a [SwipeTick] event carrying the sampled [velocity].
  const SwipeTick(this.velocity);

  /// Swipe speed in px/ms.
  final double velocity;

  @override
  List<Object?> get props => [velocity];
}

/// The device was shaken.
class RattleShaken extends RattleEvent {
  /// Creates a [RattleShaken] event.
  const RattleShaken();
}
