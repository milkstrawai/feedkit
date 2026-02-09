# frozen_string_literal: true

require "test_helper"
require_relative "../support/dummy_base"

module Feedkit
  class ScheduleMatchingWeekTest < ActiveSupport::TestCase
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Normalization
      include Feedkit::Schedule::Matching
    end

    test "due? matches even ISO weeks when week: :even is configured" do
      time = Time.zone.parse("2024-10-14 06:00:00") # Monday

      assert_predicate time.to_date.cweek, :even?

      schedule = Dummy.new(period: :week, at: { hour: 6, weekday: :monday, week: :even })

      assert schedule.due?(time)
    end

    test "due? matches odd ISO weeks when week: :odd is configured" do
      time = Time.zone.parse("2024-10-07 06:00:00") # Monday (previous ISO week)

      assert_predicate time.to_date.cweek, :odd?

      schedule = Dummy.new(period: :week, at: { hour: 6, weekday: :monday, week: :odd })

      assert schedule.due?(time)
    end

    test "due? rejects non-matching ISO week parity" do
      time = Time.zone.parse("2024-10-14 06:00:00") # even ISO week

      assert_predicate time.to_date.cweek, :even?

      schedule = Dummy.new(period: :week, at: { hour: 6, weekday: :monday, week: :odd })

      assert_not schedule.due?(time)
    end
  end
end
