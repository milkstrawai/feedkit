# frozen_string_literal: true

require "test_helper"
require_relative "support/dummy_base"

module Feedkit
  class ScheduleNormalizationTest < ActiveSupport::TestCase
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Normalization
    end

    test "normalize_weekday maps symbols to wday integers" do
      schedule = Dummy.new(period: :day, at: {})

      assert_equal 1, schedule.send(:normalize_weekday, :monday)
      assert_equal 0, schedule.send(:normalize_weekday, :sunday)
    end

    test "normalize_weekday preserves unknown symbols" do
      schedule = Dummy.new(period: :day, at: {})

      assert_equal :nope, schedule.send(:normalize_weekday, :nope)
    end

    test "normalize_weekday normalizes arrays and ranges" do
      schedule = Dummy.new(period: :day, at: {})

      assert_equal [1, 3], schedule.send(:normalize_weekday, %i[monday wednesday])
      assert_equal(2..5, schedule.send(:normalize_weekday, :tuesday..:friday))
    end

    test "normalize_month maps symbols to month integers" do
      schedule = Dummy.new(period: :day, at: {})

      assert_equal 1, schedule.send(:normalize_month, :january)
      assert_equal 12, schedule.send(:normalize_month, :december)
    end

    test "normalize_month preserves unknown symbols" do
      schedule = Dummy.new(period: :day, at: {})

      assert_equal :nope, schedule.send(:normalize_month, :nope)
    end

    test "normalize_month normalizes arrays and ranges" do
      schedule = Dummy.new(period: :day, at: {})

      assert_equal [1, 6, 12], schedule.send(:normalize_month, %i[january june december])
      assert_equal(1..3, schedule.send(:normalize_month, :january..:march))
    end

    test "normalize_weekday_value_list expands scalars, arrays, and ranges" do
      schedule = Dummy.new(period: :day, at: {})

      assert_equal [1], schedule.send(:normalize_weekday_value_list, :monday)
      assert_equal [1, 3], schedule.send(:normalize_weekday_value_list, %i[monday wednesday])
      assert_equal [2, 3, 4, 5], schedule.send(:normalize_weekday_value_list, :tuesday..:friday)
    end

    test "normalize_month_value_list expands scalars, arrays, and ranges" do
      schedule = Dummy.new(period: :day, at: {})

      assert_equal [1], schedule.send(:normalize_month_value_list, :january)
      assert_equal [1, 6, 12], schedule.send(:normalize_month_value_list, %i[january june december])
      assert_equal [1, 2, 3], schedule.send(:normalize_month_value_list, :january..:march)
    end

    test "normalize_day_value_list expands scalars and arrays" do
      schedule = Dummy.new(period: :day, at: {})
      time = Time.zone.parse("2024-02-10 00:00:00") # leap year, Feb has 29 days

      assert_equal [15], schedule.send(:normalize_day_value_list, 15, time)
      assert_equal [1, 29], schedule.send(:normalize_day_value_list, %i[first last], time)
    end

    test "normalize_day_value_list expands ranges (including nested ranges in arrays)" do
      schedule = Dummy.new(period: :day, at: {})
      time = Time.zone.parse("2024-02-10 00:00:00") # leap year, Feb has 29 days

      assert_equal [1, 2, 3], schedule.send(:normalize_day_value_list, 1..3, time)
      assert_equal [1, 2, 3, 29], schedule.send(:normalize_day_value_list, [1..3, :last], time)
    end

    test "normalize_day_endpoint resolves :first and :last" do
      schedule = Dummy.new(period: :day, at: {})
      time = Time.zone.parse("2024-02-10 00:00:00") # leap year, Feb has 29 days

      assert_equal 1, schedule.send(:normalize_day_endpoint, :first, time)
      assert_equal 29, schedule.send(:normalize_day_endpoint, :last, time)
      assert_equal 15, schedule.send(:normalize_day_endpoint, 15, time)
    end

    test "normalize_range normalizes day ranges with symbolic endpoints" do
      schedule = Dummy.new(period: :day, at: {})
      time = Time.zone.parse("2024-10-15 00:00:00")

      assert_equal(1..31, schedule.send(:normalize_range, :day, :first..:last, time))
      assert_equal(1...31, schedule.send(:normalize_range, :day, :first...:last, time))
    end

    test "normalize_range is a no-op for non-day ranges" do
      schedule = Dummy.new(period: :day, at: {})
      time = Time.zone.parse("2024-10-15 00:00:00")

      range = 2..5

      assert_equal range, schedule.send(:normalize_range, :weekday, range, time)
    end
  end
end
