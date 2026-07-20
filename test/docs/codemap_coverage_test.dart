// Guards docs/CODEMAP.md freshness: every lib/ directory that contains
// hand-written Dart files must be mentioned in the codemap, so new files
// or features can't silently escape the map.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every lib/ directory with Dart files appears in docs/CODEMAP.md', () {
    final codemap = File('docs/CODEMAP.md').readAsStringSync();
    final missing = <String>[];
    // `listSync(recursive: true)` yields only the *contents* of `lib/`,
    // never `lib/` itself, so the root directory (which directly holds
    // main.dart) must be added back in explicitly.
    final libRoot = Directory('lib');
    final dirs = <Directory>[
      libRoot,
      ...libRoot.listSync(recursive: true).whereType<Directory>(),
    ];
    for (final entity in dirs) {
      final hasDart = entity.listSync().whereType<File>().any(
        (f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'),
      );
      if (!hasDart) continue;
      final path = entity.path.replaceAll(r'\', '/');
      // A plain `codemap.contains(path)` would let the root `lib` path
      // false-pass: `lib` is a leading substring of every other path in
      // the doc (`lib/core/di`, `lib/main.dart`, ...), so it would always
      // be "found" even if never mentioned on its own. Require the match
      // not be immediately followed by a path-continuation character, so
      // `lib` only counts as found when the doc references it standalone
      // (e.g. `` `lib` ``), not merely as a prefix of a deeper path.
      final pattern = RegExp('${RegExp.escape(path)}(?![\\w./-])');
      if (!pattern.hasMatch(codemap)) missing.add(path);
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Add these directories to docs/CODEMAP.md:\n${missing.join('\n')}',
    );
  });
}
