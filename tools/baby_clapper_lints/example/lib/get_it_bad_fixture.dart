// Fixture: avoid_get_it_in_widgets — referencing `sl` or `GetIt` outside DI
// setup (and outside main.dart) must be flagged. Unlike the import-URI
// rules above, this rule inspects a *resolved* element (node.element), so
// both imports here must genuinely resolve — this package depends on
// get_it directly and imports its own injection_container.dart fixture.
// ignore_for_file: unused_local_variable
import 'package:baby_clapper_lints_example/core/di/injection_container.dart';
import 'package:get_it/get_it.dart';

class BadWidget {
  void build() {
    // expect_lint: avoid_get_it_in_widgets
    final locator = sl;
    // expect_lint: avoid_get_it_in_widgets
    final instance = GetIt.instance;
  }
}
