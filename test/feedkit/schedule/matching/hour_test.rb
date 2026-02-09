# frozen_string_literal: true

require "test_helper"
require_relative "../support/dummy_base"

module Feedkit
  class ScheduleMatchingHourTest < ActiveSupport::TestCase
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Normalization
      include Feedkit::Schedule::Matching
    end

    test "due? returns true when hour matches exactly" do
      schedule = Dummy.new(period: :day, at: { hour: 6 })

      travel_to(Time.zone.parse("2024-10-15 06:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns true when hour matches with different minutes" do
      schedule = Dummy.new(period: :day, at: { hour: 6 })

      travel_to(Time.zone.parse("2024-10-15 06:30:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when hour does not match" do
      schedule = Dummy.new(period: :day, at: { hour: 6 })

      travel_to(Time.zone.parse("2024-10-15 07:00:00")) do
        assert_not schedule.due?
      end
    end

    test "due? returns true when hour is in array" do
      schedule = Dummy.new(period: :day, at: { hour: [6, 12, 18] })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when hour is not in array" do
      schedule = Dummy.new(period: :day, at: { hour: [6, 12, 18] })

      travel_to(Time.zone.parse("2024-10-15 09:00:00")) do
        assert_not schedule.due?
      end
    end
  end
end
