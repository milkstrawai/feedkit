# frozen_string_literal: true

require "test_helper"
require_relative "../support/dummy_base"

module Feedkit
  class ScheduleMatchingMonthTest < ActiveSupport::TestCase
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Normalization
      include Feedkit::Schedule::Matching
    end

    test "due? returns true when month matches exactly" do
      schedule = Dummy.new(period: :year, at: { month: 1 })

      travel_to(Time.zone.parse("2025-01-01 00:30:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when month does not match" do
      schedule = Dummy.new(period: :year, at: { month: :january })

      travel_to(Time.zone.parse("2025-02-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    test "due? returns true when month is within symbolic range" do
      schedule = Dummy.new(period: :year, at: { month: :january..:march })

      travel_to(Time.zone.parse("2025-02-01 00:30:00")) do
        assert_predicate schedule, :due?
      end

      travel_to(Time.zone.parse("2025-03-01 00:30:00")) do
        assert_predicate schedule, :due?
      end

      travel_to(Time.zone.parse("2025-06-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    test "due? returns false when month is outside symbolic range" do
      schedule = Dummy.new(period: :year, at: { month: :january..:march })

      travel_to(Time.zone.parse("2025-06-15 12:00:00")) do
        assert_not schedule.due?
      end
    end

    test "due? returns true when month is in symbolic array" do
      schedule = Dummy.new(period: :year, at: { month: %i[january march june] })

      travel_to(Time.zone.parse("2025-03-01 00:30:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when month is not in symbolic array" do
      schedule = Dummy.new(period: :year, at: { month: %i[january march june] })

      travel_to(Time.zone.parse("2025-02-15 12:00:00")) do
        assert_not schedule.due?
      end
    end
  end
end
