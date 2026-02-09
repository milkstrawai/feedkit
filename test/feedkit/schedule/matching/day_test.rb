# frozen_string_literal: true

require "test_helper"
require_relative "../support/dummy_base"

module Feedkit
  class ScheduleMatchingDayTest < ActiveSupport::TestCase
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Normalization
      include Feedkit::Schedule::Matching
    end

    test "due? returns true when day of month matches" do
      schedule = Dummy.new(period: :month, at: { day: 1 })

      travel_to(Time.zone.parse("2024-10-01 00:30:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when day of month does not match" do
      schedule = Dummy.new(period: :month, at: { day: 1 })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    test "due? returns true on first day of month when day: :first" do
      schedule = Dummy.new(period: :month, at: { day: :first })

      travel_to(Time.zone.parse("2024-10-01 00:30:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns true on last day of month when day: :last" do
      schedule = Dummy.new(period: :month, at: { day: :last })

      travel_to(Time.zone.parse("2024-10-31 00:30:00")) do # Oct has 31 days
        assert_predicate schedule, :due?
      end
    end

    test "due? supports symbolic day values inside arrays" do
      schedule = Dummy.new(period: :month, at: { day: %i[first last] })

      travel_to(Time.zone.parse("2024-10-01 00:30:00")) do
        assert_predicate schedule, :due?
      end

      travel_to(Time.zone.parse("2024-10-31 00:30:00")) do
        assert_predicate schedule, :due?
      end

      travel_to(Time.zone.parse("2024-10-15 00:30:00")) do
        assert_not schedule.due?
      end
    end

    test "due? supports symbolic day values inside ranges" do
      schedule = Dummy.new(period: :month, at: { day: :first..:last })

      travel_to(Time.zone.parse("2024-10-15 00:30:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? supports numeric day ranges" do
      schedule = Dummy.new(period: :month, at: { day: 1..15 })

      travel_to(Time.zone.parse("2024-10-10 00:30:00")) do
        assert_predicate schedule, :due?
      end

      travel_to(Time.zone.parse("2024-10-20 00:30:00")) do
        assert_not schedule.due?
      end
    end

    test "due? respects exclusive numeric day ranges" do
      schedule = Dummy.new(period: :month, at: { day: 1...15 })

      travel_to(Time.zone.parse("2024-10-14 00:30:00")) do
        assert_predicate schedule, :due?
      end

      travel_to(Time.zone.parse("2024-10-15 00:30:00")) do
        assert_not schedule.due?
      end
    end
  end
end
