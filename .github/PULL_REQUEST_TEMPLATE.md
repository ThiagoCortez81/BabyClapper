<!--
  Thanks for contributing to BabyClapper! Keep this PR focused on one concern
  (CLAUDE.md §6 "surgical edits"). Delete sections that don't apply.
-->

## What & why

<!-- One or two sentences: what does this change do, and why? Link any issue. -->

Closes #

## Type of change

- [ ] Feature
- [ ] Bug fix
- [ ] Refactor (no behaviour change)
- [ ] Docs / chore

## Verification (CLAUDE.md §4 done-bar)

CI enforces all of these, but confirm you ran them locally:

- [ ] `fvm flutter analyze` — 0 issues
- [ ] `fvm dart run custom_lint` — 0 issues
- [ ] baby_clapper_lints fixtures — `( cd tools/baby_clapper_lints/example && fvm dart run custom_lint )`
- [ ] `fvm dart run bloc_tools:bloc lint lib` — 0 issues
- [ ] `fvm dart format lib test tools` — tree is clean
- [ ] `fvm flutter test` — 100% green

## Project-specific checklist

- [ ] **Wiki:** if I changed how a feature is *used* (new feature, setting, gesture, haptic/sound pattern, renamed label, changed default/limit), I updated the [wiki](https://github.com/ThiagoCortez81/BabyClapper/wiki) (`BabyClapper.wiki.git`) in the same change.
- [ ] **CLAUDE.md:** if I changed architecture or a convention, I updated `CLAUDE.md`.
- [ ] **Tests:** I added or updated tests for this change.
- [ ] **Lints:** any new custom_lint rule ships an `// expect_lint:` fixture in `tools/baby_clapper_lints/example/`.
