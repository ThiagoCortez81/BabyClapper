// Fixture: a non-bloc widget file is exempt from bloc_depends_on_abstractions.
// ignore_for_file: uri_does_not_exist, unused_import
import 'package:baby_clapper/features/rattle/data/haptic_service_impl.dart';
import 'package:vibration/vibration.dart';
// Non-bloc file: wakelock_plus import must NOT be flagged by bloc_depends_on_abstractions.
import 'package:wakelock_plus/wakelock_plus.dart';
