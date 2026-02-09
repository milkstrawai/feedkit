# frozen_string_literal: true

require "test_helper"
require_relative "../support/dummy_base"

module Feedkit
  class ScheduleMatchingWeekdayTest < ActiveSupport::TestCase
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Normalization
      include Feedkit::Schedule::Matching
    end

    test "due? returns true when weekday matches exactly" do
      schedule = Dummy.new(period: :week, at: { weekday: 1 }) # Monday

      travel_to(Time.zone.parse("2024-10-14 00:30:00")) do # Monday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when weekday does not match" do
      schedule = Dummy.new(period: :week, at: { weekday: 1 }) # Monday

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday
        assert_not schedule.due?
      end
    end

    test "due? returns true when symbolic weekday matches" do
      schedule = Dummy.new(period: :week, at: { weekday: :monday })

      travel_to(Time.zone.parse("2024-10-14 00:30:00")) do # Monday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when symbolic weekday does not match" do
      schedule = Dummy.new(period: :week, at: { weekday: :monday })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday
        assert_not schedule.due?
      end
    end

    test "due? returns true when weekday is within symbolic range" do
      schedule = Dummy.new(period: :day, at: { weekday: :tuesday..:friday })

      travel_to(Time.zone.parse("2024-10-16 00:30:00")) do # Wednesday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when weekday is outside symbolic range" do
      schedule = Dummy.new(period: :day, at: { weekday: :tuesday..:friday })

      travel_to(Time.zone.parse("2024-10-14 12:00:00")) do # Monday
        assert_not schedule.due?
      end
    end

    test "due? returns true when weekday is in symbolic array" do
      schedule = Dummy.new(period: :day, at: { weekday: %i[monday wednesday friday] })

      travel_to(Time.zone.parse("2024-10-16 00:30:00")) do # Wednesday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when weekday is not in symbolic array" do
      schedule = Dummy.new(period: :day, at: { weekday: %i[monday wednesday friday] })

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday
        assert_not schedule.due?
      end
    end

    test "due? returns true when weekday is within numeric range" do
      schedule = Dummy.new(period: :day, at: { weekday: 2..5 }) # Tue-Fri

      travel_to(Time.zone.parse("2024-10-16 00:30:00")) do # Wednesday
        assert_predicate schedule, :due?
      end
    end

    test "due? returns false when weekday is outside numeric range" do
      schedule = Dummy.new(period: :day, at: { weekday: 2..5 }) # Tue-Fri

      travel_to(Time.zone.parse("2024-10-14 12:00:00")) do # Monday
        assert_not schedule.due?
      end
    end
  end
end
