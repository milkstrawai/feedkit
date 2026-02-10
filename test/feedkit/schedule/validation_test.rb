# frozen_string_literal: true

require "test_helper"
require_relative "support/dummy_base"

module Feedkit
  class ScheduleValidationTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
    Dummy = Class.new(Feedkit::ScheduleTestDummyBase) do
      include Feedkit::Schedule::Validation
    end

    test "raises ArgumentError for unknown period" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :fortnight, at: { hour: 6 })
      end

      assert_match(/Unknown period: fortnight/, error.message)
    end

    test "raises ArgumentError for unknown condition type" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :day, at: { unknown: 6 })
      end

      assert_match(/Unknown condition type: unknown/, error.message)
    end

    test "raises ArgumentError when conditions is not a Hash" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :day, at: "invalid")
      end

      assert_match(/conditions must be a Hash/, error.message)
    end

    test "raises ArgumentError for hour out of range" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :day, at: { hour: 24 })
      end

      assert_match(/Invalid hour value: 24/, error.message)
    end

    test "raises ArgumentError for day out of range" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :month, at: { day: 32 })
      end

      assert_match(/Invalid day value: 32/, error.message)
    end

    test "raises ArgumentError for weekday out of range" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :week, at: { weekday: 0 })
      end

      assert_match(/Invalid weekday value: 0/, error.message)
    end

    test "raises ArgumentError for month out of range" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :year, at: { month: 13 })
      end

      assert_match(/Invalid month value: 13/, error.message)
    end

    test "accepts week parity values :odd and :even" do
      schedule = Dummy.new(period: :week, at: { week: :odd })

      assert_equal({ week: :odd }, schedule.conditions)

      schedule = Dummy.new(period: :week, at: { week: :even })

      assert_equal({ week: :even }, schedule.conditions)
    end

    test "raises ArgumentError for invalid week parity value" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :week, at: { week: :nope })
      end

      assert_match(/Invalid week value: nope/, error.message)
    end

    test "raises ArgumentError for week parity ranges" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :week, at: { week: :odd..:even })
      end

      assert_match(/Invalid week value: odd\.\.even/, error.message)
    end

    test "raises ArgumentError for week parity arrays" do
      error = assert_raises(ArgumentError) do
        Dummy.new(period: :week, at: { week: %i[odd even] })
      end

      assert_match(/Invalid week value: \[:odd, :even\]/, error.message)
    end

    test "accepts symbolic day endpoints :first and :last" do
      schedule = Dummy.new(period: :month, at: { day: :first })

      assert_equal({ day: :first }, schedule.conditions)

      schedule = Dummy.new(period: :month, at: { day: :last })

      assert_equal({ day: :last }, schedule.conditions)
    end

    test "accepts integer months 1-12" do
      schedule = Dummy.new(period: :year, at: { month: 1 })

      assert_equal({ month: 1 }, schedule.conditions)

      schedule = Dummy.new(period: :year, at: { month: 12 })

      assert_equal({ month: 12 }, schedule.conditions)
    end

    test "accepts valid hour range 0-23" do
      schedule = Dummy.new(period: :day, at: { hour: 0..23 })

      assert_equal({ hour: 0..23 }, schedule.conditions)
    end

    test "accepts all symbolic weekday names" do
      %i[sunday monday tuesday wednesday thursday friday saturday].each do |day|
        schedule = Dummy.new(period: :week, at: { weekday: day })

        assert_equal({ weekday: day }, schedule.conditions)
      end
    end

    test "accepts all symbolic month names" do
      %i[january february march april may june july august september october november december].each do |month|
        schedule = Dummy.new(period: :year, at: { month: month })

        assert_equal({ month: month }, schedule.conditions)
      end
    end

    test "private helpers return nil for unknown condition types (validation)" do
      schedule = Dummy.new(period: :day, at: { hour: 6 })

      assert_nil schedule.send(:validate_scalar_value!, :unknown, 1)
    end
  end
end
