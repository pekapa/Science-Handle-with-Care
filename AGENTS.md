# Working on Science, Handle With Care

Read `README.md`, `docs/decisions.md`, `docs/architecture.md` and
`docs/testing.md` before changing gameplay. `DESIGN.md` provides context;
`docs/decisions.md` distinguishes accepted rules from tuning proposals. Update the relevant
current rule instead of silently turning open questions into requirements.

## Documentation

All documents describe current state; none is an append-only log. Git preserves
history. Put each change in its proper home and revise or replace existing text
rather than appending dated decisions, user quotations or investigation diaries.
Keep README focused on the mod and contributor entry points, DESIGN on intended
gameplay, decisions on current accepted rules and proposals, architecture on
boundaries, testing on reproducible checks, and open questions on unresolved work.
Keep private feasibility probes out of published source; port necessary evidence
into maintained tests that exercise production code.

## Scope and invariants

- Target the latest stable and experimental Factorio builds through the shared
  test target configuration. Consult official API/local runtime docs matching the
  tested build; use real-engine evidence for uncertain behavior.
- Every nonempty supported science subset is producible, including useless mixes.
  No automatic correction, rejection or blackening because research cannot use it.
- No player-selected mixer recipe. At crafting start, consume one pack of each
  science type present to determine output. Prefer minimal raw-pack buffering;
  allow buffering when needed for a practical implementation.
- One visible placed Lab with exactly one physical science input slot. Wrong
  science blocks that slot until removed. Matching input becomes native research
  credit; committed health may round downward. A persistent hidden native worker
  supplies research, power and modules because native lab inventories cannot enforce
  the shared untyped slot. Preserve credit through mining in the Lab item tags.
- Single-science mixer output is the same ordinary pack after 60 powered ticks.
  Only combined science is fragile: fresh health is 100%, nine wear points leave
  10%, and ten points denature it.
- Wear is charged once at pickup, including blocked delivery and save/reload.
  Denatured science stacks and receives no additional wear.
- Do not claim the foundation is playable or promise untested compatibility.

## Implementation discipline

- Backward compatibility is not maintained during development. Change or remove
  interfaces, identifiers, saved-state formats and gameplay as needed, even when
  existing saves or setups break. Update callers, tests and docs together; remove
  superseded code. Do not add compatibility layers, legacy aliases or migrations
  solely to preserve earlier development versions. Save/reload continuity within
  the current version remains required.
- Follow the boundaries in `docs/architecture.md`; keep entrypoints thin and pure
  rules independent of Factorio globals. Add modules only when needed.
- Persist simulation state in `storage`. Keep multiplayer behavior deterministic,
  handle invalid entities/lifecycle events, and avoid per-tick world scans.
- Preserve items and research credit on blocked paths, removal and reload.
- Prefer readable, small changes. No speculative framework, broad rewrite,
  unrelated formatting or dependency without a concrete need.
- Player-facing text belongs in locale files once gameplay is implemented.
- Prefer Factorio's existing windows, widgets, styles and inventory operations.
  Before replacing native UI, establish the specific API limitation and reuse all
  supported parts. Preserve default machine layout and interactions; do not treat
  familiar base-game behavior as an invitation to redesign it.

## Tests and verification

- For gameplay changes and bug fixes, reproduce the behavior in a failing test
  first when feasible; implement, then refactor. Document any exception.
- Test outcomes: inventories, wear, produced items, research credit and reload
  continuity. Do not substitute empty mocks for Factorio inventories or entities.
- Pure unit tests cover pure rules. Real engine scenarios cover Factorio behavior.
  A test-only fixture must exercise production code when claiming mod correctness.
- GUI changes need evidence at the changed boundary: real production window
  construction, production transfer actions, genuine client input, and rendered
  appearance are distinct checks. Inventory or helper tests do not prove that a
  window opens, a mouse event reaches its handler, or the layout looks correct.
- Reproduce GUI regressions through the real engine when feasible. Inspect a
  rendered capture for layout changes and exercise actual client input for input
  changes. If a required check cannot run, report that layer as unverified rather
  than describing the interface as verified or complete.
- Follow `docs/testing.md` commands. Missing tools, timeouts, engine errors and
  missing completion assertions are failures, never a reported pass.
- Report exact checks run and any checks not run. Do not add coverage quotas or
  tests that only repeat the implementation.
- Identify the tested package/revision and each suite run, including optional GUI
  checks. A default test-suite pass is not evidence that omitted suites passed;
  absent screenshots or a missing graphical client are not successful GUI checks.
- Use isolated configuration/mod/save/output directories. Never change or install
  into the player's normal game, touch personal saves, or terminate their game.

## Open source and delivery

- Project-owned source/docs are MIT licensed. Keep notices with distributions.
  Do not copy proprietary Factorio assets, binaries, saves or third-party work
  without permission and attribution. Reference base-game assets by path.
- Never commit credentials, local paths/configuration, logs, saves or builds.
- CI must run without secrets for public pull requests. Never execute untrusted
  PR code on a persistent self-hosted runner or through `pull_request_target`.
- Do not publish releases, upload to the mod portal, or push without authorization.
