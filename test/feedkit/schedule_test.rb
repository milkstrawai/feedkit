# frozen_string_literal: true

require "test_helper"

module Feedkit
  class ScheduleTest < ActiveSupport::TestCase
    test "initializes with period and conditions" do
      schedule = Feedkit::Schedule.new(period: :day, at: { hour: 6 })

      assert_equal :day, schedule.period
      assert_equal({ hour: 6 }, schedule.conditions)
    end

    test "initializes with superseded_by as empty array by default" do
      schedule = Feedkit::Schedule.new(period: :day, at: { hour: 6 })

      assert_empty schedule.superseded_by
    end

    test "initializes with superseded_by array" do
      schedule = Feedkit::Schedule.new(period: :day, at: { hour: 6 }, superseded_by: [:weekly])

      assert_equal ["weekly"], schedule.superseded_by
    end

    test "wraps single superseded_by value in array" do
      schedule = Feedkit::Schedule.new(period: :day, at: { hour: 6 }, superseded_by: :weekly)

      assert_equal ["weekly"], schedule.superseded_by
    end

    test "due? applies implicit hour default on the Schedule wrapper" do
      travel_to(Time.zone.parse("2024-10-15 00:30:00")) do
        due = Feedkit::Schedule.new(period: :day, at: {}).due?

        assert due
      end

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do
        due = Feedkit::Schedule.new(period: :day, at: {}).due?

        assert_not due
      end
    end

    test "due? applies implicit weekday default on the Schedule wrapper" do
      weekly = Feedkit::Schedule.new(period: :week, at: { hour: 7 }) # defaults weekday: :monday
      travel_to(Time.zone.parse("2024-10-14 07:30:00")) do # Monday
        due = weekly.due?

        assert due
      end

      travel_to(Time.zone.parse("2024-10-15 07:30:00")) do # Tuesday
        due = weekly.due?

        assert_not due
      end
    end

    test "due? applies implicit year defaults on the Schedule wrapper" do
      yearly = Feedkit::Schedule.new(period: :year, at: {}) # defaults month: :january, day: 1, hour: 0
      travel_to(Time.zone.parse("2025-01-01 00:30:00")) do
        due = yearly.due?

        assert due
      end

      travel_to(Time.zone.parse("2025-06-01 00:30:00")) do
        due = yearly.due?

        assert_not due
      end
    end

    test "effective_conditions applies implicit month day when day is omitted" do
      schedule = Feedkit::Schedule.new(period: :month, at: { hour: 6 })

      assert_equal({ hour: 6, day: 1 }, schedule.effective_conditions)
    end

    test "effective_conditions does not apply implicit year month/day when explicit values are provided" do
      schedule = Feedkit::Schedule.new(period: :year, at: { month: :march, day: 15 })

      assert_equal({ hour: 0, month: :march, day: 15 }, schedule.effective_conditions)
    end

    test "period_start_at on the Schedule wrapper normalizes time and delegates to PeriodStart" do
      schedule = Feedkit::Schedule.new(period: :day, at: { hour: [6, 12] })
      time = Time.zone.parse("2024-10-15 12:30:00")

      assert_equal Time.zone.parse("2024-10-15 12:00:00"), schedule.period_start_at(time)

      schedule = Feedkit::Schedule.new(period: :hour, at: {})
      time = Object.new
      def time.beginning_of_hour = :ok

      assert_equal :ok, schedule.period_start_at(time)
    end
  end
end
