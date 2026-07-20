import 'package:baby_clapper/features/rattle/domain/rattle_math.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_bloc.dart';
import 'package:baby_clapper/features/rattle/presentation/bloc/rattle_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A single pointer's last sampled position and timestamp, used to compute
/// swipe velocity independently per finger.
typedef _PointerTrack = ({Offset pos, Duration ts});

/// Edge-to-edge surface: pointer moves are throttled to ~40 ms ticks and
/// dispatched as [SwipeTick]s carrying the sampled swipe velocity.
///
/// Multiple fingers are tracked independently (keyed by [PointerEvent.
/// pointer]) so a baby palming the screen with several fingers at once
/// doesn't conflate one finger's move with another's last-known position.
class RattleScreen extends StatefulWidget {
  /// Creates the fullscreen rattle gesture surface.
  const RattleScreen({super.key});

  @override
  State<RattleScreen> createState() => _RattleScreenState();
}

class _RattleScreenState extends State<RattleScreen> {
  final Map<int, _PointerTrack> _tracks = {};

  void _reset(PointerEvent event) {
    _tracks.remove(event.pointer);
  }

  void _onMove(PointerMoveEvent event) {
    final ts = event.timeStamp;
    final last = _tracks[event.pointer];
    if (last == null) {
      _tracks[event.pointer] = (pos: event.position, ts: ts);
      return;
    }
    final dt = ts - last.ts;
    if (dt < kSwipeThrottle) return;

    final distance = (event.position - last.pos).distance;
    final velocity = velocityFromDelta(distance, dt);
    context.read<RattleBloc>().add(SwipeTick(velocity));
    _tracks[event.pointer] = (pos: event.position, ts: ts);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _reset,
      onPointerMove: _onMove,
      onPointerUp: _reset,
      onPointerCancel: _reset,
      child: const ColoredBox(
        // TODO(theme): read from context.appPalette once theming lands.
        color: Color(0xFF1B1B2F),
        child: SizedBox.expand(),
      ),
    );
  }
}
