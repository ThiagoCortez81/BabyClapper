// Fixture: the app entry point — a sanctioned site for `sl` and `GetIt`;
// must NOT be flagged by avoid_get_it_in_widgets because the path ends with
// lib/main.dart.
// ignore_for_file: unused_local_variable
import 'package:baby_clapper_lints_example/core/di/injection_container.dart';
import 'package:get_it/get_it.dart';

void main() {
  final locator = sl;
  final instance = GetIt.instance;
}
