import 'package:equatable/equatable.dart';

/// State for `RattleBloc`.
class RattleState extends Equatable {
  /// Creates a [RattleState].
  const RattleState({this.ready = false});

  /// Whether the bloc has finished initializing (services wired up).
  final bool ready;

  /// Returns a copy of this state with the given fields replaced.
  RattleState copyWith({bool? ready}) =>
      RattleState(ready: ready ?? this.ready);

  @override
  List<Object?> get props => [ready];
}
