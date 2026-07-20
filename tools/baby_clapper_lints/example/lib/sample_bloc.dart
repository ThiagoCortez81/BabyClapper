// Fixture: bloc_depends_on_abstractions — a *_bloc.dart importing concrete
// data/vibration/soundpool instead of an abstract service type.
// ignore_for_file: uri_does_not_exist, unused_import

// expect_lint: bloc_depends_on_abstractions
import 'package:baby_clapper/features/rattle/data/haptic_service_impl.dart';
// expect_lint: bloc_depends_on_abstractions
import 'package:vibration/vibration.dart';
// expect_lint: bloc_depends_on_abstractions
import 'package:soundpool/soundpool.dart';
// expect_lint: bloc_depends_on_abstractions
import 'package:audio_session/audio_session.dart';
// expect_lint: bloc_depends_on_abstractions
import 'package:sensors_plus/sensors_plus.dart';
// expect_lint: bloc_depends_on_abstractions
import 'package:wakelock_plus/wakelock_plus.dart';

// Allowed — abstract domain service type:
import 'package:baby_clapper/features/rattle/domain/haptic_service.dart';
