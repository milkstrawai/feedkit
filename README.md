# Feedkit

[![Gem Version](https://badge.fury.io/rb/feedkit.svg)](https://badge.fury.io/rb/feedkit)
[![Build Status](https://github.com/milkstrawai/feedkit/actions/workflows/main.yml/badge.svg)](https://github.com/milkstrawai/feedkit/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Scheduled feed generation for Rails applications.**

Feedkit is a Rails engine for scheduled feed generation. You write generator classes that return a hash. Feedkit runs them on a schedule, stores the results, and deduplicates per schedule period.

## Table of Contents

- [The Problem](#the-problem)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Generators](#generators)
- [Scheduling](#scheduling)
- [Ad-hoc Generators](#ad-hoc-generators)
- [Querying Feeds](#querying-feeds)
- [Configuration](#configuration)
- [How It Works](#how-it-works)
- [Requirements](#requirements)
- [Roadmap](#roadmap)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## The Problem

Most applications end up needing periodic snapshots: cost reports, usage digests, analytics rollups. In practice, that code gets spread across cron, one-off jobs, and service objects. After a few report types, you start re-solving the same problems (when to run, how to avoid duplicates, where to store the output).

Feedkit keeps it in one place: define a generator class, declare its schedule, and implement `#data`. Feedkit takes care of dispatching, persistence, and "once per period" deduplication.

## Installation

Add Feedkit to your Gemfile:

```ruby
gem 'feedkit'
```

Install and run the generator:

```bash
bundle install
rails generate feedkit:install
rails db:migrate
```

This creates three things:
- `config/initializers/feedkit.rb`: configuration file
- A migration for the `feedkit_feeds` table
- `app/generators/`: directory for your generator classes

> **Note:** Feedkit requires PostgreSQL. The migration uses `jsonb` for the feed data column.

If your models use UUID primary keys, pass the `--owner_id_type` option:

```bash
rails generate feedkit:install --owner_id_type=uuid
```

## Quick Start

### 1. Include `FeedsOwner` in your model

```ruby
class Organization < ApplicationRecord
  include Feedkit::FeedsOwner
end
```

This adds a `feeds` association to the model.

### 2. Generate a feed generator

```bash
rails generate feedkit:generator CostOverview --owner Organization
```

This creates `app/generators/cost_overview.rb` and a corresponding test file.

### 3. Implement the `#data` method

```ruby
class CostOverview < Feedkit::Generator
  owned_by Organization

  every :day, at: { hour: 13 }, as: :daily
  every :week, at: { hour: 14, weekday: :tuesday }, as: :weekly

  private

  def data
    return if owner.costs.none?

    {
      total_cost: owner.costs.sum(:amount),
      top_services: owner.costs.group(:service).sum(:amount).sort_by { |_, v| -v }.first(5)
    }
  end
end
```

Return a hash to create a feed, or `nil` to skip.

### 4. Schedule the dispatch job

Feedkit needs a cron-like scheduler to trigger `Feedkit::DispatchJob` periodically. With [GoodJob](https://github.com/bensheldon/good_job):

```ruby
# config/initializers/good_job.rb
config.cron = {
  feedkit_dispatch: { cron: '0 * * * *', class: 'Feedkit::DispatchJob' }
}
```

With [Sidekiq](https://github.com/sidekiq/sidekiq):

```yaml
# config/sidekiq_cron.yml
feedkit_dispatch:
  cron: '0 * * * *'
  class: Feedkit::DispatchJob
```

How often you run the dispatch job depends on your schedules. Running it hourly works well for most setups. Feedkit does not backfill missed ticks; it only enqueues work for schedules that are due at the time `DispatchJob` runs.

## Generators

A generator is a class that inherits from `Feedkit::Generator`. It defines what data to produce, for which owner model, and on what schedule.

```ruby
class WeeklyDigest < Feedkit::Generator
  owned_by Organization

  # Optional: override the stored feed_type (defaults to the underscored class name)
  # feed_type :weekly_digest

  every :week, at: { hour: 9, weekday: :monday }, as: :weekly

  private

  def data
    {
      active_users: owner.users.active.count,
      new_signups: owner.users.where(created_at: 1.week.ago..).count
    }
  end
end
```

### Auto-registration

Generators register themselves when their class is loaded. There is no manual registration step.

In production (with `config.eager_load = true`), Rails loads application code at boot, so generator classes under `app/generators/` are loaded and registered automatically.

In development, Feedkit calls `eager_load_generators!` before each dispatch cycle to ensure all generator files are loaded from the configured `generator_paths`.

### The `#data` method

This is the only method you need to implement. It receives no arguments. Access the owner via the `owner` accessor.

- Return a **Hash** to create a feed record with that data
- Return **`nil`** to skip feed creation (useful for conditional feeds)

### The `owned_by` macro

Use `owned_by` when you want `Feedkit::DispatchJob` to run a generator automatically for every record of an owner model. It tells Feedkit what class to iterate over when dispatching scheduled runs.

If you only run a generator manually, `owned_by` is optional. You can still pass an owner instance to `new`, and Feedkit will persist the feed under that owner.

### The `owner` accessor

Inside your generator, `owner` gives you the model instance that the feed belongs to. Use it to query for the data you need.

### The `feed_type` macro

By default, Feedkit stores feeds under a `feed_type` derived from the generator class name (including namespaces). You can override it per generator:

```ruby
class CostOverview < Feedkit::Generator
  owned_by Organization

  feed_type :cost_overview

  private

  def data
    { total_cost: owner.costs.sum(:amount) }
  end
end
```

### The `options` accessor

Generators accept arbitrary keyword arguments that are available via the `options` accessor. This is useful for passing context when triggering generators manually:

```ruby
class AuditReport < Feedkit::Generator
  owned_by Organization

  private

  def data
    {
      findings: owner.run_audit,
      requested_by: options[:requested_by],
      scope: options[:scope] || "full"
    }
  end
end

# Pass options when calling
AuditReport.new(organization, requested_by: "admin@example.com", scope: "billing").call
```

### Generator scaffolding

The generator generator (yes) creates a class file and a test:

```bash
# With an owner
rails generate feedkit:generator MonthlySummary --owner Organization

# Without an owner (for ownerless generators)
rails generate feedkit:generator SystemHealthCheck
```

## Scheduling

### The `every` DSL

Each generator can define one or more schedules:

```ruby
every <period>, at: <conditions>, as: <name>, superseded_by: <names>
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `every` | Yes | One of: `:hour`, `:day`, `:week`, `:month`, `:year` |
| `at:` | Yes | Hash of conditions that must all match for the schedule to be due |
| `as:` | No | Name for this schedule (must be unique per generator; auto-generated from period and conditions if omitted) |
| `superseded_by:` | No | Array of schedule names that take precedence when both are due |

### Conditions

Conditions are AND-ed together. All must match for the schedule to fire.

| Condition | Values | Examples |
|-----------|--------|---------|
| `hour:` | `0..23` | `hour: 6`, `hour: [6, 12, 18]`, `hour: 9..17` |
| `day:` | `1..31`, `:first`, `:last` | `day: 1`, `day: :last`, `day: 1..15` |
| `weekday:` | `1..7` (ISO: Monday = `1`, Sunday = `7`), `:monday`..`:sunday` | `weekday: :monday`, `weekday: :monday..:friday` |
| `week:` | `:odd`, `:even` (ISO week parity, `Date#cweek`) | `week: :odd` |
| `month:` | `1..12`, `:january`..`:december` | `month: :january`, `month: :january..:march` |

All condition types except `week:` accept integers, symbols (where applicable), ranges, and arrays. `week:` only accepts `:odd` or `:even`.

Ranges/arrays expand to multiple matching values. If that results in multiple occurrences within a period (for example `every :day, at: { hour: [6, 12, 18] }`), Feedkit treats each occurrence as a distinct tick and generates one feed per tick (per owner).

### Examples

```ruby
# Every day at 6 AM
every :day, at: { hour: 6 }, as: :daily

# Every Monday at 7 AM
every :week, at: { hour: 7, weekday: :monday }, as: :weekly

# Every Monday at 7 AM on odd ISO weeks
every :week, at: { hour: 7, weekday: :monday, week: :odd }

# First of every month at 8 AM
every :month, at: { hour: 8, day: 1 }, as: :monthly

# January 15 at 9 AM (yearly)
every :year, at: { hour: 9, month: :january, day: 15 }, as: :annual

# Weekdays only at 6 AM
every :day, at: { hour: 6, weekday: :monday..:friday }

# Any of these hours (one feed per scheduled hour)
every :day, at: { hour: [6, 12, 18] }

# Q1 only
every :month, at: { hour: 6, day: 1, month: :january..:march }
```

### Schedule precedence with `superseded_by`

When a generator has multiple schedules, you sometimes want a longer-period schedule to take precedence. For example, you don't want both a daily and weekly feed generated on the same Monday morning.

```ruby
class CostOverview < Feedkit::Generator
  owned_by Organization

  every :day, at: { hour: 6 }, as: :daily, superseded_by: %i[weekly monthly]
  every :week, at: { hour: 6, weekday: :monday }, as: :weekly, superseded_by: :monthly
  every :month, at: { hour: 6, day: 1 }, as: :monthly

  private

  def data
    { total: owner.costs.sum(:amount) }
  end
end
```

On a regular Tuesday at 6 AM, only `:daily` fires. On a Monday at 6 AM, only `:weekly` fires (`:daily` is superseded). On the 1st of the month at 6 AM if it's a Monday, only `:monthly` fires (both `:daily` and `:weekly` are superseded).

### Deduplication

Scheduled generators automatically deduplicate within their period. If a generator already created a feed for the current schedule period (for example, for the current scheduled hour), calling it again is a no-op. This prevents duplicates if the dispatch job runs more than once in the same period.

Deduplication is based on **schedule boundaries**, not a sliding `period.ago` window. For scheduled feeds, Feedkit computes a `period_start_at` timestamp from the schedule and stores it on the feed record. Subsequent runs in the same schedule period are skipped.

`period_start_at` is computed in the app's time zone. Around DST transitions, some local times don't exist or repeat; Feedkit skips ticks that can't be represented as a stable local timestamp.

Deduplication only applies when a generator is invoked as a scheduled run (with `period_name:` set, which is what `DispatchJob` does) and an owner is present. Ad-hoc calls do not deduplicate, including calling a scheduled generator without `period_name:` and ownerless generators.

## Ad-hoc Generators

Not every generator needs a schedule. You can define generators that are triggered manually from controllers, jobs, or the console.

### Ownerless generator

```ruby
class SystemHealthReport < Feedkit::Generator
  private

  def data
    {
      memory_usage: calculate_memory,
      cpu_load: calculate_cpu,
      checked_at: Time.current
    }
  end
end

# Trigger from anywhere
SystemHealthReport.new.call
```

### Run a generator for an owner

```ruby
class AuditReport < Feedkit::Generator
  private

  def data
    { findings: owner.run_audit }
  end
end

# Trigger manually
AuditReport.new(organization).call
```

If you want this generator to be dispatched automatically on a schedule, add `owned_by Organization` and one or more `every ...` schedules.

Ad-hoc generators (no schedule) skip deduplication entirely. Each call creates a new feed.

## Querying Feeds

### Via the owner association

```ruby
organization.feeds                                    # All feeds
organization.feeds.by_type(:cost_overview)            # Filter by generator
organization.feeds.by_type(:cost_overview).recent(10) # Latest 10
organization.feeds.latest                             # Ordered by newest first
```

### Via the Feed model directly

```ruby
Feedkit::Feed.for_owner(organization).latest
Feedkit::Feed.by_type(:system_health_report).recent(5)
```

### Available scopes

| Scope | Description |
|-------|-------------|
| `for_owner(owner)` | Feeds belonging to a specific owner |
| `by_type(type)` | Feeds of a specific generator type |
| `latest` | Ordered by `created_at DESC` |
| `recent(n)` | Latest `n` feeds (default: 50) |

### Feed attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `owner` | Polymorphic | The owner record (can be `nil` for ownerless feeds) |
| `feed_type` | String | Derived from the generator class name (namespaces included, e.g., `"admin_digest"` for `Admin::Digest`) |
| `period_name` | String | Schedule name (e.g., `"daily"`, `"weekly"`) or `nil` for ad-hoc |
| `period_start_at` | DateTime | Start of the schedule period used for deduplication (`nil` for ad-hoc feeds) |
| `data` | Hash | The payload returned by `#data` (stored as `jsonb`) |
| `created_at` | DateTime | When the feed was generated |

## Configuration

The install generator creates `config/initializers/feedkit.rb`:

```ruby
Feedkit.configure do |config|
  # Table name for the feeds table (default: 'feedkit_feeds')
  # config.table_name = 'feedkit_feeds'

  # Association name added to owner models (default: :feeds)
  # config.association_name = :feeds

  # Glob paths to load generator classes in development (default: ['app/generators/**/*.rb'])
  # Only used when Rails eager loading is disabled (development mode)
  # config.generator_paths = ['app/generators/**/*.rb']

  # Primary key type for the owner_id column (default: :bigint)
  # Set before running the migration
  config.owner_id_type = :bigint

  # Logger instance (defaults to Rails.logger)
  # config.logger = Rails.logger
end
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `table_name` | `'feedkit_feeds'` | Database table name for feed records |
| `association_name` | `:feeds` | Name of the `has_many` association added to owner models |
| `generator_paths` | `['app/generators/**/*.rb']` | Glob patterns for loading generators in development |
| `owner_id_type` | `:bigint` | Column type for `owner_id` (`:bigint` or `:uuid`) |
| `logger` | `Rails.logger` | Logger instance for Feedkit's internal logging |

## How It Works

### Architecture

Feedkit has four main components:

1. **Generator**: Base class with auto-registration via Ruby's `inherited` hook. When you define `class MyGen < Feedkit::Generator`, it is added to the registry.

2. **Registry**: Tracks generator classes. Knows which are scheduled, which have owners, and which are due at a given time.

3. **DispatchJob**: An ActiveJob that asks the registry what is due, then enqueues a `GenerateFeedJob` for each owner of each due generator.

4. **GenerateFeedJob**: An ActiveJob that instantiates one generator for one owner, calls `#data`, and persists the result as a `Feedkit::Feed` record.

### Dispatch Flow

```
DispatchJob (hourly cron)
  → Registry.due_at(Time.current)
    → For each due generator:
      → generator.owner_class.find_each do |owner|
        → GenerateFeedJob.perform_later(..., period_name:, scheduled_at:)
          → generator.new(owner, period_name:).call(run_at: scheduled_at)
            → Check deduplication (skip if already generated this period)
            → Call #data (skip if nil)
            → Create Feedkit::Feed record
```

### Error Handling

`GenerateFeedJob` logs errors and does not re-raise:

- If an **owner is deleted** between dispatch and execution, the job is skipped.
- If a **generator raises**, the error is logged via `Feedkit.logger` (with a full backtrace).

### Database Schema

The migration creates a `feedkit_feeds` table with three indexes:

| Index | Columns | Purpose |
|-------|---------|---------|
| `created_at` | `created_at` | Ordering and pagination |
| `idx_feedkit_feeds_lookup` | `owner_type, owner_id, feed_type, created_at` | Querying feeds for an owner |
| `idx_feedkit_feeds_dedup` | `owner_type, owner_id, feed_type, period_name, period_start_at` | Deduplication checks |

## Requirements

- **Ruby** >= 3.2
- **Rails** >= 7.0
- **PostgreSQL** (for `jsonb` column support)
- **ActiveJob backend** (GoodJob, Sidekiq, etc.) with cron/recurring job support

## Roadmap

Features we're considering for future releases:

- [ ] **MySQL support**: Adapter pattern for non-PostgreSQL databases (Feedkit uses `jsonb` today)
- [ ] **Feed retention policies**: Auto-cleanup of old feeds based on age or count per generator
- [ ] **Callbacks**: `before_generate` and `after_generate` hooks for logging, notifications, or side effects
- [ ] **Web dashboard**: Mountable engine with a UI for browsing feeds and monitoring generator health
- [ ] **Feed versioning**: Schema version tracking for feed data to handle generator changes over time

Have a feature request? [Open an issue](https://github.com/milkstrawai/feedkit/issues) to discuss it!

## Development

### Setup

```bash
git clone https://github.com/milkstrawai/feedkit.git
cd feedkit
bundle install
```

### Running Tests

```bash
# Run test suite
bundle exec rake test

# Run with coverage report
bundle exec rake test && open coverage/index.html

# Run linter
bundle exec rubocop

# Run both (default rake task)
bundle exec rake

# Run against a specific Rails version
bundle exec appraisal rails-8-1 rake test

# Run against all Rails versions
bundle exec appraisal rake test
```

### Test Coverage

Coverage is enforced:
- Line coverage: 100%
- Branch coverage: 95%

### Multi-version Testing

Feedkit is tested against a matrix of Ruby and Rails versions using [Appraisal](https://github.com/thoughtbot/appraisal):

| | Rails 7.0 | Rails 7.1 | Rails 7.2 | Rails 8.0 | Rails 8.1 |
|---|---|---|---|---|---|
| Ruby 3.2 | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ruby 3.3 | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ruby 3.4 | n/a | ✓ | ✓ | ✓ | ✓ |

## Contributing

Contributions are welcome. Typical flow:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Guidelines

- Write tests for new features
- Follow existing code style (RuboCop will help)
- Update documentation as needed
- Keep commits focused and atomic

### Reporting Issues

Found a bug? Please open an issue with:
- Ruby and Rails versions
- Steps to reproduce
- Expected vs actual behavior

## License

Feedkit is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
