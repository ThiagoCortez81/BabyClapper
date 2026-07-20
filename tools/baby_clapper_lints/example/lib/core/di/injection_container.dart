// Fixture: DI setup — the sanctioned site for `sl` and `GetIt`; must NOT be
// flagged by avoid_get_it_in_widgets because the path is under
// lib/core/di/. Referenced (resolved) by get_it_bad_fixture.dart so that
// rule's node.element check has something real to match against.
import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

void registerDependencies() {
  sl.registerLazySingleton<int>(() => 1);
}
