# frozen_string_literal: true

require "test_helper"
require_relative "../support/dummy_base"

module Feedkit
  class ScheduleMatchingMiscTest < ActiveSupport::TestCase
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Normalization
      include Feedkit::Schedule::Matching
    end

    test "due? accepts explicit time parameter" do
      schedule = Dummy.new(period: :day, at: { hour: 6 })
      time = Time.zone.parse("2024-10-15 06:00:00")

      assert schedule.due?(time)
    end

    test "due? uses implicit hour 0 when hour is omitted" do
      schedule = Dummy.new(period: :day, at: {})

      travel_to(Time.zone.parse("2024-10-15 00:30:00")) do
        assert_predicate schedule, :due?
      end

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    test "due? returns true when all conditions match" do
      schedule = Dummy.new(period: :day, at: { hour: 6, weekday: 2..5 })

      travel_to(Time.zone.parse("2024-10-16 06:00:00")) do # Wednesday 6 AM
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when only hour matches" do
      schedule = Dummy.new(period: :day, at: { hour: 6, weekday: 2..5 })

      travel_to(Time.zone.parse("2024-10-14 06:00:00")) do # Monday 6 AM
        assert_not schedule.due?
      end
    end

    test "private helpers return nil for unknown condition types (matching)" do
      schedule = Dummy.new(period: :day, at: { hour: 6 })
      time = Time.zone.parse("2024-10-15 06:00:00")

      assert_nil schedule.send(:actual_value_for, :unknown, time)
      assert_nil schedule.send(:symbolic_match?, :first, :hour, time)
    end
  end
end
