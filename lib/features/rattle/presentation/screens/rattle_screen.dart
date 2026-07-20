import 'package:baby_clapper/core/rattle_math.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Edge-to-edge surface: pointer moves are throttled to ~40 ms ticks and
/// dispatched as [SwipeTick]s carrying the sampled swipe velocity.
class RattleScreen extends StatefulWidget {
  /// Creates the fullscreen rattle gesture surface.
  const RattleScreen({super.key});

  @override
  State<RattleScreen> createState() => _RattleScreenState();
}

class _RattleScreenState extends State<RattleScreen> {
  static const _throttle = Duration(milliseconds: 40);
  Offset? _lastPos;
  Duration? _lastTs;

  void _reset([_]) {
    _lastPos = null;
    _lastTs = null;
  }

  void _onMove(PointerMoveEvent event) {
    final ts = event.timeStamp;
    final lastPos = _lastPos;
    final lastTs = _lastTs;
    if (lastPos == null || lastTs == null) {
      _lastPos = event.position;
      _lastTs = ts;
      return;
    }
    final dt = ts - lastTs;
    if (dt < _throttle) return;

    final distance = (event.position - lastPos).distance;
    final velocity = velocityFromDelta(distance, dt);
    context.read<RattleBloc>().add(SwipeTick(velocity));
    _lastPos = event.position;
    _lastTs = ts;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _reset,
      onPointerMove: _onMove,
      onPointerUp: _reset,
      onPointerCancel: _reset,
      child: const ColoredBox(
        color: Color(0xFF1B1B2F),
        child: SizedBox.expand(),
      ),
    );
  }
}
