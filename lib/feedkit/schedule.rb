# frozen_string_literal: true

require_relative "schedule/constants"
require_relative "schedule/validation"
require_relative "schedule/normalization"
require_relative "schedule/naming"
require_relative "schedule/matching"
require_relative "schedule/period_start_calculator"

module Feedkit
  class Schedule
    include Normalization
    include Validation
    include Matching
    include Naming

    attr_reader :period_name, :period, :conditions, :superseded_by

    def initialize(period:, at:, as: nil, superseded_by: [])
      @period = period.to_sym
      @conditions = at
      @superseded_by = Array(superseded_by).map(&:to_s)

      validate_period!
      validate_conditions!

      @period_name = (as || generate_period_name).to_s
    end

    def due?(time = Time.current)
      time = normalize_time(time)
      matches_effective_conditions?(time)
    end

    # Returns the start of the current schedule period for the provided time.
    # This is used for deduplication ("once per period") and is intentionally
    # based on schedule boundaries rather than a sliding window (e.g. `1.day.ago`).
    def period_start_at(time = Time.current)
      time = normalize_time(time)
      PeriodStartCalculator.new(schedule: self, time:).call
    end

    def effective_conditions
      @effective_conditions ||= implicit_conditions_for_period.merge(conditions)
    end

    private

    def matches_effective_conditions?(time)
      effective_conditions.all? { |type, value| matches?(type, value, time) }
    end

    def implicit_conditions_for_period
      implicit_hour_conditions.merge(implicit_date_conditions)
    end

    def implicit_hour_conditions
      return {} if conditions.key?(:hour) || period == :hour

      { hour: 0 }
    end

    def implicit_date_conditions
      return implicit_weekday_conditions if period == :week
      return implicit_month_day_conditions if period == :month
      return implicit_year_conditions if period == :year

      {}
    end

    def implicit_weekday_conditions
      conditions.key?(:weekday) ? {} : { weekday: :monday }
    end

    def implicit_month_day_conditions
      conditions.key?(:day) ? {} : { day: 1 }
    end

    def implicit_year_conditions
      implicit = {}
      implicit[:month] = :january unless conditions.key?(:month)
      implicit[:day] = 1 unless conditions.key?(:day)
      implicit
    end

    def normalize_time(time)
      time.respond_to?(:in_time_zone) ? time.in_time_zone : time
    end
  end
end
