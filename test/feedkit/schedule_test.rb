# frozen_string_literal: true

require "test_helper"

module Feedkit
  class ScheduleTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
    # Basic initialization
    test "initializes with period and conditions" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 })

      assert_equal 1.day, schedule.period
      assert_equal({ hour: 6 }, schedule.conditions)
    end

    test "generates period_name from period and conditions" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 })

      assert_equal "d1_h6", schedule.period_name
    end

    test "uses explicit name when as: is provided" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 }, as: :daily)

      assert_equal "daily", schedule.period_name
    end

    test "initializes with superseded_by as empty array by default" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 })

      assert_empty schedule.superseded_by
    end

    test "initializes with superseded_by array" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 }, superseded_by: [:weekly])

      assert_equal ["weekly"], schedule.superseded_by
    end

    test "wraps single superseded_by value in array" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 }, superseded_by: :weekly)

      assert_equal ["weekly"], schedule.superseded_by
    end

    # Period name generation
    test "generates period_name for hourly schedule" do
      schedule = Feedkit::Schedule.new(every: 1.hour, at: {})

      assert_equal "h1", schedule.period_name
    end

    test "generates period_name for daily schedule with hour" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 })

      assert_equal "d1_h6", schedule.period_name
    end

    test "generates period_name for weekly schedule with hour and weekday" do
      schedule = Feedkit::Schedule.new(every: 1.week, at: { hour: 7, weekday: 1 })

      assert_equal "w1_h7_wd1", schedule.period_name
    end

    test "generates period_name for biweekly schedule" do
      schedule = Feedkit::Schedule.new(every: 2.weeks, at: { hour: 6, week: :even })

      assert_equal "w2_h6_weven", schedule.period_name
    end

    test "generates period_name for monthly schedule with day" do
      schedule = Feedkit::Schedule.new(every: 1.month, at: { hour: 6, day: 1 })

      assert_equal "m1_h6_d1", schedule.period_name
    end

    test "generates period_name with seconds fallback for custom periods" do
      schedule = Feedkit::Schedule.new(every: 3.hours, at: {})

      assert_equal "s10800", schedule.period_name
    end

    test "generates period_name with range conditions" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6, weekday: 1..5 })

      assert_equal "d1_h6_wd1-5", schedule.period_name
    end

    test "generates period_name with array conditions" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: [6, 12, 18] })

      assert_equal "d1_h6-12-18", schedule.period_name
    end

    # Hour matching
    test "due? returns true when hour matches exactly" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 })

      travel_to(Time.zone.parse("2024-10-15 06:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns true when hour matches with different minutes" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 })

      travel_to(Time.zone.parse("2024-10-15 06:30:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when hour does not match" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 })

      travel_to(Time.zone.parse("2024-10-15 07:00:00")) do
        assert_not schedule.due?
      end
    end

    # Weekday matching
    test "due? returns true when weekday matches exactly" do
      schedule = Feedkit::Schedule.new(every: 1.week, at: { weekday: 1 }) # Monday

      travel_to(Time.zone.parse("2024-10-14 12:00:00")) do # Monday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when weekday does not match" do
      schedule = Feedkit::Schedule.new(every: 1.week, at: { weekday: 1 }) # Monday

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday
        assert_not schedule.due?
      end
    end

    # Symbolic weekday names
    test "due? returns true when symbolic weekday matches" do
      schedule = Feedkit::Schedule.new(every: 1.week, at: { weekday: :monday })

      travel_to(Time.zone.parse("2024-10-14 12:00:00")) do # Monday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when symbolic weekday does not match" do
      schedule = Feedkit::Schedule.new(every: 1.week, at: { weekday: :monday })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday
        assert_not schedule.due?
      end
    end

    test "due? returns true when weekday is within symbolic range" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { weekday: :tuesday..:friday })

      travel_to(Time.zone.parse("2024-10-16 12:00:00")) do # Wednesday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when weekday is outside symbolic range" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { weekday: :tuesday..:friday })

      travel_to(Time.zone.parse("2024-10-14 12:00:00")) do # Monday
        assert_not schedule.due?
      end
    end

    test "due? returns true when weekday is in symbolic array" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { weekday: %i[monday wednesday friday] })

      travel_to(Time.zone.parse("2024-10-16 12:00:00")) do # Wednesday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when weekday is not in symbolic array" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { weekday: %i[monday wednesday friday] })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday
        assert_not schedule.due?
      end
    end

    test "generates same period_name for symbolic and numeric weekday" do
      numeric = Feedkit::Schedule.new(every: 1.week, at: { hour: 7, weekday: 1 })
      symbolic = Feedkit::Schedule.new(every: 1.week, at: { hour: 7, weekday: :monday })

      assert_equal numeric.period_name, symbolic.period_name
    end

    # Range conditions
    test "due? returns true when weekday is within range" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { weekday: 2..5 }) # Tue-Fri

      travel_to(Time.zone.parse("2024-10-16 12:00:00")) do # Wednesday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when weekday is outside range" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { weekday: 2..5 }) # Tue-Fri

      travel_to(Time.zone.parse("2024-10-14 12:00:00")) do # Monday
        assert_not schedule.due?
      end
    end

    # Array conditions
    test "due? returns true when value is in array" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: [6, 12, 18] })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when value is not in array" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: [6, 12, 18] })

      travel_to(Time.zone.parse("2024-10-15 09:00:00")) do
        assert_not schedule.due?
      end
    end

    # Multiple conditions (AND logic)
    test "due? returns true when all conditions match" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6, weekday: 2..5 })

      travel_to(Time.zone.parse("2024-10-16 06:00:00")) do # Wednesday 6 AM
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when only hour matches" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6, weekday: 2..5 })

      travel_to(Time.zone.parse("2024-10-14 06:00:00")) do # Monday 6 AM
        assert_not schedule.due?
      end
    end

    # Day of month
    test "due? returns true when day of month matches" do
      schedule = Feedkit::Schedule.new(every: 1.month, at: { day: 1 })

      travel_to(Time.zone.parse("2024-10-01 12:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when day of month does not match" do
      schedule = Feedkit::Schedule.new(every: 1.month, at: { day: 1 })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    test "due? returns true on first day of month when day: :first" do
      schedule = Feedkit::Schedule.new(every: 1.month, at: { day: :first })

      travel_to(Time.zone.parse("2024-10-01 12:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns true on last day of month when day: :last" do
      schedule = Feedkit::Schedule.new(every: 1.month, at: { day: :last })

      travel_to(Time.zone.parse("2024-10-31 12:00:00")) do # Oct has 31 days
        assert_predicate schedule, :due?
      end
    end

    # Week number
    test "due? returns true when week number matches" do
      schedule = Feedkit::Schedule.new(every: 1.week, at: { week: 42 })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Week 42
        assert_predicate schedule, :due?
      end
    end

    test "due? returns true on even weeks when week: :even" do
      schedule = Feedkit::Schedule.new(every: 1.week, at: { week: :even })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Week 42 (even)
        assert_predicate schedule, :due?
      end
    end

    test "due? returns true on odd weeks when week: :odd" do
      schedule = Feedkit::Schedule.new(every: 1.week, at: { week: :odd })

      travel_to(Time.zone.parse("2024-10-08 12:00:00")) do # Week 41 (odd)
        assert_predicate schedule, :due?
      end
    end

    # Empty conditions
    test "due? returns true when conditions are empty" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: {})

      assert_predicate schedule, :due?
    end

    # Accepts explicit time parameter
    test "due? accepts explicit time parameter" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 6 })
      time = Time.zone.parse("2024-10-15 06:00:00")

      assert schedule.due?(time)
    end

    # Condition type validation
    test "raises ArgumentError for unknown condition type" do
      error = assert_raises(ArgumentError) do
        Feedkit::Schedule.new(every: 1.day, at: { unknown: 6 })
      end

      assert_match(/Unknown condition type: unknown/, error.message)
    end

    test "raises ArgumentError when conditions is not a Hash" do
      error = assert_raises(ArgumentError) do
        Feedkit::Schedule.new(every: 1.day, at: "invalid")
      end

      assert_match(/conditions must be a Hash/, error.message)
    end

    # Hour validation
    test "raises ArgumentError for hour out of range" do
      error = assert_raises(ArgumentError) do
        Feedkit::Schedule.new(every: 1.day, at: { hour: 24 })
      end

      assert_match(/Invalid hour value: 24/, error.message)
    end

    # Day validation
    test "raises ArgumentError for day out of range" do
      error = assert_raises(ArgumentError) do
        Feedkit::Schedule.new(every: 1.month, at: { day: 32 })
      end

      assert_match(/Invalid day value: 32/, error.message)
    end

    # Weekday validation
    test "raises ArgumentError for weekday out of range" do
      error = assert_raises(ArgumentError) do
        Feedkit::Schedule.new(every: 1.week, at: { weekday: 7 })
      end

      assert_match(/Invalid weekday value: 7/, error.message)
    end

    # Week validation
    test "raises ArgumentError for week out of range" do
      error = assert_raises(ArgumentError) do
        Feedkit::Schedule.new(every: 2.weeks, at: { week: 54 })
      end

      assert_match(/Invalid week value: 54/, error.message)
    end

    # Valid edge cases
    test "accepts valid hour range 0-23" do
      schedule = Feedkit::Schedule.new(every: 1.day, at: { hour: 0..23 })

      assert_equal({ hour: 0..23 }, schedule.conditions)
    end

    test "accepts all symbolic weekday names" do
      %i[sunday monday tuesday wednesday thursday friday saturday].each do |day|
        schedule = Feedkit::Schedule.new(every: 1.week, at: { weekday: day })

        assert_equal({ weekday: day }, schedule.conditions)
      end
    end

    # Yearly schedule support
    test "generates period_name for yearly schedule" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { hour: 6, month: :january, day: 15 })

      assert_equal "y1_h6_m1_d15", schedule.period_name
    end

    test "due? returns true when month matches exactly" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { month: 1 })

      travel_to(Time.zone.parse("2025-01-15 12:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when month does not match" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { month: :january })

      travel_to(Time.zone.parse("2025-02-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    # Month validation
    test "raises ArgumentError for month out of range" do
      error = assert_raises(ArgumentError) do
        Feedkit::Schedule.new(every: 1.year, at: { month: 13 })
      end

      assert_match(/Invalid month value: 13/, error.message)
    end

    test "accepts all symbolic month names" do
      %i[january february march april may june july august september october november december].each do |month|
        schedule = Feedkit::Schedule.new(every: 1.year, at: { month: month })

        assert_equal({ month: month }, schedule.conditions)
      end
    end

    # Month range and array conditions
    test "due? returns true when month is within symbolic range" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { month: :january..:march })

      travel_to(Time.zone.parse("2025-02-15 12:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when month is outside symbolic range" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { month: :january..:march })

      travel_to(Time.zone.parse("2025-06-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    test "due? returns true when month is in symbolic array" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { month: %i[january march june] })

      travel_to(Time.zone.parse("2025-03-15 12:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when month is not in symbolic array" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { month: %i[january march june] })

      travel_to(Time.zone.parse("2025-02-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    test "generates period_name for month range" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { month: :january..:march })

      assert_equal "y1_m1-3", schedule.period_name
    end

    test "generates period_name for month array" do
      schedule = Feedkit::Schedule.new(every: 1.year, at: { month: %i[january june december] })

      assert_equal "y1_m1-6-12", schedule.period_name
    end
  end
end
