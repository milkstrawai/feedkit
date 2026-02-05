# frozen_string_literal: true

require "test_helper"

module Feedkit
  class SchedulableTest < ActiveSupport::TestCase
    class TestGenerator
      include Feedkit::Schedulable

      schedule every: 1.day, at: { hour: 6 }, as: :daily, superseded_by: %i[weekly monthly]
      schedule every: 1.week, at: { hour: 6, weekday: 1 }, as: :weekly, superseded_by: :monthly
      schedule every: 1.month, at: { hour: 6, day: 1 }, as: :monthly
    end

    test "schedules_due returns only daily on regular Tuesday" do
      travel_to(Time.zone.parse("2024-10-15 06:00:00")) do # Tuesday
        due = TestGenerator.schedules_due

        assert_equal ["daily"], due.map(&:period_name)
      end
    end

    test "schedules_due returns only weekly on regular Monday (daily skipped)" do
      travel_to(Time.zone.parse("2024-10-14 06:00:00")) do # Monday, not 1st
        due = TestGenerator.schedules_due

        assert_equal ["weekly"], due.map(&:period_name)
      end
    end

    test "schedules_due returns only monthly on 1st of month Monday (daily and weekly skipped)" do
      travel_to(Time.zone.parse("2025-09-01 06:00:00")) do # Monday, 1st of month
        due = TestGenerator.schedules_due

        assert_equal ["monthly"], due.map(&:period_name)
      end
    end

    test "schedules_due returns only monthly on 1st of month non-Monday (daily skipped)" do
      travel_to(Time.zone.parse("2024-10-01 06:00:00")) do # Tuesday, 1st of month
        due = TestGenerator.schedules_due

        assert_equal ["monthly"], due.map(&:period_name)
      end
    end

    test "find_schedule returns nil when period_name is nil" do
      assert_nil TestGenerator.find_schedule(nil)
    end

    test "find_schedule returns schedule by name" do
      schedule = TestGenerator.find_schedule(:daily)

      assert_equal "daily", schedule.period_name
    end
  end
end
