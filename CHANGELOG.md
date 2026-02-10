## [Unreleased]

### Changed

- **Breaking:** Weekday numbering switched from Ruby `wday` (0=Sunday..6=Saturday) to ISO `cwday` (1=Monday..7=Sunday)

## [0.2.0] - 2026-02-09

### Added

- `:year` schedules with `month:` and `day:` conditions

### Changed

- Schedule periods are now symbolic (`:hour`, `:day`, `:week`, `:month`, `:year`) instead of arbitrary `ActiveSupport::Duration` values
- Schedule matching, naming, validation, and period boundary calculations were refactored into focused modules
- Deduplication uses schedule boundaries (`period_start_at`) rather than sliding time windows
- `week:` condition now supports ISO week parity only (`:odd`/`:even`)

### Fixed

- Handle DST transitions when calculating `period_start_at` (skip ambiguous/non-existent local ticks)
- Documentation clarifications around weekday integers (`wday`), multi-tick schedules (ranges/arrays), and when deduplication applies

## [0.1.0] - 2026-02-05

### Added

- Base `Feedkit::Generator` class with auto-registration via Ruby's `inherited` hook
- Schedule DSL with support for `hour`, `day`, `weekday`, `week`, and `month` conditions
- Arbitrary `ActiveSupport::Duration` periods (`1.hour`, `1.day`, `1.week`, `1.month`, `1.year`, etc.)
- Schedule precedence with `superseded_by` to prevent overlapping feeds
- Automatic deduplication within schedule periods
- `Feedkit::Registry` for tracking and querying registered generators
- `Feedkit::Feed` model with `for_owner`, `by_type`, `latest`, and `recent` query scopes
- `Feedkit::FeedsOwner` concern for adding feeds association to owner models
- `Feedkit::DispatchJob` for scheduled feed generation via ActiveJob
- `Feedkit::GenerateFeedJob` for per-owner feed generation with error handling
- Ad-hoc generator support (ownerless and unscheduled generators)
- Generator `options` accessor for passing arbitrary context
- Configurable table name, association name, generator paths, owner ID type, and logger
- Rails generator for installation (`rails generate feedkit:install`)
- Rails generator for scaffolding generators (`rails generate feedkit:generator NAME`)
- UUID primary key support via `--owner_id_type=uuid` option
- PostgreSQL `jsonb` storage for feed data
