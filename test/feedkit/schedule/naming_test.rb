# frozen_string_literal: true

require "test_helper"
require_relative "support/dummy_base"

module Feedkit
  class ScheduleNamingTest < ActiveSupport::TestCase
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Normalization
      include Feedkit::Schedule::Matching
      include Feedkit::Schedule::Naming
    end

    test "uses explicit name when as: is provided" do
      schedule = Dummy.new(period: :day, at: { hour: 6 }, as: :daily)

      assert_equal "daily", schedule.period_name
    end

    test "generates period_name for hourly schedule" do
      schedule = Dummy.new(period: :hour, at: {})

      assert_equal "h1", schedule.period_name
    end

    test "generates period_name for daily schedule with hour" do
      schedule = Dummy.new(period: :day, at: { hour: 6 })

      assert_equal "d1_h6", schedule.period_name
    end

    test "generates period_name for weekly schedule with hour and weekday" do
      schedule = Dummy.new(period: :week, at: { hour: 7, weekday: 1 })

      assert_equal "w1_h7_wd1", schedule.period_name
    end

    test "generates period_name for weekly schedule with week parity" do
      schedule = Dummy.new(period: :week, at: { hour: 7, weekday: 1, week: :odd })

      assert_equal "w1_h7_wd1_wkodd", schedule.period_name
    end

    test "generates period_name for monthly schedule with day" do
      schedule = Dummy.new(period: :month, at: { hour: 6, day: 1 })

      assert_equal "m1_h6_d1", schedule.period_name
    end

    test "generates period_name for yearly schedule" do
      schedule = Dummy.new(period: :year, at: { hour: 6, day: 15, month: :january })

      assert_equal "y1_h6_d15_m1", schedule.period_name
    end

    test "generates period_name with range conditions" do
      schedule = Dummy.new(period: :day, at: { hour: 6, weekday: 1..5 })

      assert_equal "d1_h6_wd1-5", schedule.period_name
    end

    test "generates period_name with array conditions" do
      schedule = Dummy.new(period: :day, at: { hour: [6, 12, 18] })

      assert_equal "d1_h6-12-18", schedule.period_name
    end

    test "generates period_name for month range" do
      schedule = Dummy.new(period: :year, at: { month: :january..:march })

      assert_equal "y1_m1-3", schedule.period_name
    end

    test "generates period_name for month array" do
      schedule = Dummy.new(period: :year, at: { month: %i[january june december] })

      assert_equal "y1_m1-6-12", schedule.period_name
    end

    test "period_name canonicalizes weekday arrays" do
      schedule = Dummy.new(period: :week, at: { hour: 7, weekday: %i[wednesday monday] })

      assert_equal "w1_h7_wd1-3", schedule.period_name
    end

    test "period_name canonicalizes day arrays with :first and :last" do
      schedule = Dummy.new(period: :month, at: { hour: 6, day: [:last, 1, :first] })

      assert_equal "m1_h6_dfirst-1-last", schedule.period_name
    end

    test "generates same period_name for symbolic and numeric weekday" do
      numeric = Dummy.new(period: :week, at: { hour: 7, weekday: 1 })
      symbolic = Dummy.new(period: :week, at: { hour: 7, weekday: :monday })

      assert_equal numeric.period_name, symbolic.period_name
    end

    test "canonicalize_array_value_for_name returns values as-is for types without a canonicalizer" do
      schedule = Dummy.new(period: :day, at: { hour: 6 })

      assert_equal [2, 1], schedule.send(:canonicalize_array_value_for_name, :week, [2, 1])
    end
  end
end
