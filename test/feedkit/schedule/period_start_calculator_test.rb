# frozen_string_literal: true

require "test_helper"
require_relative "support/dummy_base"

module Feedkit
  DummyScheduleForPeriodStartCalculator = Class.new(Feedkit::ScheduleTestDummyBase) do
    include Feedkit::Schedule::Normalization
    include Feedkit::Schedule::Matching
  end

  class SchedulePeriodStartCalculatorHourTest < ActiveSupport::TestCase
    test "period_start_at floors hourly schedules to the beginning of the hour" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :hour, at: {})
      time = Time.zone.parse("2024-10-15 06:30:45")

      assert_equal Time.zone.parse("2024-10-15 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at works when time does not support in_time_zone" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :hour, at: {})
      time = Object.new
      def time.beginning_of_hour = :ok

      assert_equal :ok, schedule.period_start_at(time)
    end
  end

  class SchedulePeriodStartCalculatorDayTest < ActiveSupport::TestCase
    test "period_start_at floors daily schedules to the matching hour tick" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :day, at: { hour: 6..8 })
      time = Time.zone.parse("2024-10-15 07:30:00")

      assert_equal Time.zone.parse("2024-10-15 07:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at uses midnight when daily schedules have no hour condition" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :day, at: {})
      time = Time.zone.parse("2024-10-15 07:30:00")

      assert_equal Time.zone.parse("2024-10-15 00:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at floors daily schedules with hour arrays to the matching hour tick" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :day, at: { hour: [18, 6, 12] })
      time = Time.zone.parse("2024-10-15 12:30:00")

      assert_equal Time.zone.parse("2024-10-15 12:00:00"), schedule.period_start_at(time)
    end
  end

  class SchedulePeriodStartCalculatorDstTest < ActiveSupport::TestCase
    test "period_start_at skips non-existent local times on DST spring forward" do
      Time.use_zone("America/New_York") do
        schedule = DummyScheduleForPeriodStartCalculator.new(period: :day, at: { hour: 2 })
        time = Time.zone.local(2024, 3, 10, 3, 5, 0)

        assert_equal Time.zone.local(2024, 3, 9, 2, 0, 0), schedule.period_start_at(time)
      end
    end

    test "period_start_at uses a stable tick for ambiguous local times on DST fall back" do
      Time.use_zone("America/New_York") do
        schedule = DummyScheduleForPeriodStartCalculator.new(period: :day, at: { hour: 1 })

        # 2024-11-03 01:30 occurs twice in America/New_York. Build the second instance from UTC.
        time = Time.utc(2024, 11, 3, 6, 30, 0).in_time_zone(Time.zone)

        assert_equal Time.zone.local(2024, 11, 3, 1, 0, 0), schedule.period_start_at(time)
      end
    end
  end

  class SchedulePeriodStartCalculatorWeekTest < ActiveSupport::TestCase
    test "period_start_at floors weekly schedules to the matching day/hour tick" do
      schedule =
        DummyScheduleForPeriodStartCalculator.new(period: :week, at: { hour: 7, weekday: :monday..:friday })
      time = Time.zone.parse("2024-10-16 07:30:00") # Wednesday

      assert_equal Time.zone.parse("2024-10-16 07:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at floors weekly schedules with weekday arrays to the matching day/hour tick" do
      schedule =
        DummyScheduleForPeriodStartCalculator.new(period: :week, at: { hour: 7, weekday: %i[wednesday monday] })
      time = Time.zone.parse("2024-10-16 07:30:00") # Wednesday

      assert_equal Time.zone.parse("2024-10-16 07:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at supports Sunday as an anchor weekday" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :week, at: { hour: 6, weekday: :sunday })
      time = Time.zone.parse("2024-10-13 06:30:00") # Sunday

      assert_equal Time.zone.parse("2024-10-13 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at for weekly schedules falls back to the previous week when the anchor is in the future" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :week, at: { hour: 6, weekday: :friday })
      time = Time.zone.parse("2024-10-14 05:00:00") # Monday

      assert_equal Time.zone.parse("2024-10-11 06:00:00"), schedule.period_start_at(time)
    end
  end

  class SchedulePeriodStartCalculatorMonthTest < ActiveSupport::TestCase
    test "period_start_at anchors monthly schedules to the configured day and hour" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :month, at: { day: :last, hour: 6 })
      time = Time.zone.parse("2024-10-31 06:30:00")

      assert_equal Time.zone.parse("2024-10-31 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at defaults monthly schedules to day 1 when no day condition is provided" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :month, at: { hour: 6 })
      time = Time.zone.parse("2024-10-20 06:30:00")

      assert_equal Time.zone.parse("2024-10-01 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at anchors monthly schedules to the earliest configured day in ranges" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :month, at: { day: 10..20, hour: 6 })
      time = Time.zone.parse("2024-10-15 06:30:00")

      assert_equal Time.zone.parse("2024-10-15 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at anchors monthly schedules to the earliest configured day in arrays" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :month, at: { day: [15, :last], hour: 6 })
      time = Time.zone.parse("2024-10-31 06:30:00")

      assert_equal Time.zone.parse("2024-10-31 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at anchors monthly schedules when day is :first" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :month, at: { day: :first, hour: 6 })
      time = Time.zone.parse("2024-10-01 06:30:00")

      assert_equal Time.zone.parse("2024-10-01 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at for monthly schedules falls back to the previous month when the anchor is in the future" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :month, at: { day: 15, hour: 6 })
      time = Time.zone.parse("2024-10-10 05:00:00")

      assert_equal Time.zone.parse("2024-09-15 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at month candidate generation skips invalid dates (e.g. April 31)" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :month, at: { day: 31 })
      time = Time.zone.parse("2024-04-15 12:00:00")

      assert_equal Time.zone.parse("2024-03-31 00:00:00"), schedule.period_start_at(time)
    end
  end

  class SchedulePeriodStartCalculatorYearTest < ActiveSupport::TestCase
    test "period_start_at returns the closest scheduled tick for yearly schedules" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :year, at: { month: :january, day: 15, hour: 6 })
      time = Time.zone.parse("2025-02-01 00:00:00")

      assert_equal Time.zone.parse("2025-01-15 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at defaults yearly schedules to January when no month condition is provided" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :year, at: { day: 15, hour: 6 })
      time = Time.zone.parse("2025-02-01 00:00:00")

      assert_equal Time.zone.parse("2025-01-15 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at anchors yearly schedules to the earliest configured month in ranges" do
      schedule =
        DummyScheduleForPeriodStartCalculator.new(period: :year, at: { month: :february..:march, day: 15, hour: 6 })
      time = Time.zone.parse("2025-03-20 00:00:00")

      assert_equal Time.zone.parse("2025-03-15 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at anchors yearly schedules to the earliest configured month in arrays" do
      schedule =
        DummyScheduleForPeriodStartCalculator.new(period: :year, at: { month: %i[march january], day: 15, hour: 6 })
      time = Time.zone.parse("2025-03-20 00:00:00")

      assert_equal Time.zone.parse("2025-03-15 06:00:00"), schedule.period_start_at(time)
    end

    test "period_start_at for yearly schedules falls back to the previous year when the anchor is in the future" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :year, at: { month: :january, day: 15, hour: 6 })
      time = Time.zone.parse("2025-01-01 00:00:00")

      assert_equal Time.zone.parse("2024-01-15 06:00:00"), schedule.period_start_at(time)
    end
  end

  class SchedulePeriodStartCalculatorErrorsTest < ActiveSupport::TestCase
    test "call raises after exhausting the search window when schedule can never be due" do
      schedule =
        DummyScheduleForPeriodStartCalculator.new(period: :day, at: { month: 2..1 }) # empty range, never matches
      time = Time.zone.parse("2024-10-15 12:00:00")

      calculator = Feedkit::Schedule::PeriodStartCalculator.new(schedule:, time:)
      assert_raises(ArgumentError) { calculator.call }
    end

    test "candidate date generation skips invalid dates (e.g. Feb 31) for yearly schedules" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :year, at: { month: :february, day: 31 })
      window_start = Time.zone.parse("2024-01-01 00:00:00")

      calculator = Feedkit::Schedule::PeriodStartCalculator.new(schedule:, time: window_start)

      assert_empty calculator.send(:candidate_dates_for_window, window_start)
    end
  end

  class SchedulePeriodStartCalculatorInternalsTest < ActiveSupport::TestCase
    test "tick candidate generation skips candidates outside the current window" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :day, at: { hour: 6 })
      window_start = Time.zone.parse("2024-10-15 00:00:00")
      window_end = window_start + 1.day
      out_of_window_date = window_start.to_date + 1

      calculator = Feedkit::Schedule::PeriodStartCalculator.new(schedule:, time: window_start)

      assert_empty calculator.send(:tick_candidates_for_date, window_start, window_end, out_of_window_date)
    end

    test "tick candidate generation skips candidates when local time construction fails (DST edge)" do
      schedule = DummyScheduleForPeriodStartCalculator.new(period: :day, at: { hour: 6 })
      time = Time.zone.parse("2024-10-15 06:30:00")

      calculator = Feedkit::Schedule::PeriodStartCalculator.new(schedule:, time:)

      window_start = Object.new
      def window_start.change(**)
        raise TZInfo::PeriodNotFound, "non-existent local time"
      end

      assert_empty calculator.send(:tick_candidates_for_date, window_start, Object.new, Date.new(2024, 10, 15))
    end
  end
end
