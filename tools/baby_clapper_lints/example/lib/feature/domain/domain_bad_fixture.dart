// Fixture: domain_no_infrastructure_imports — a domain/ file importing
// Flutter/vibration/soundpool/data instead of staying pure Dart.
// ignore_for_file: uri_does_not_exist, unused_import

// expect_lint: domain_no_infrastructure_imports
import 'package:flutter/material.dart';
// expect_lint: domain_no_infrastructure_imports
import 'dart:ui';
// expect_lint: domain_no_infrastructure_imports, platform_io_outside_io_files
import 'dart:io';
// expect_lint: domain_no_infrastructure_imports
import 'package:vibration/vibration.dart';
// expect_lint: domain_no_infrastructure_imports
import 'package:soundpool/soundpool.dart';
// expect_lint: domain_no_infrastructure_imports
import 'package:audio_session/audio_session.dart';
// expect_lint: domain_no_infrastructure_imports
import 'package:sensors_plus/sensors_plus.dart';
// expect_lint: domain_no_infrastructure_imports
import 'package:wakelock_plus/wakelock_plus.dart';
// expect_lint: domain_no_infrastructure_imports
import 'package:baby_clapper/features/rattle/data/haptic_service_impl.dart';

// Allowed in domain — must NOT be flagged:
import 'package:equatable/equatable.dart';
import 'package:baby_clapper/features/rattle/domain/haptic_service.dart';
