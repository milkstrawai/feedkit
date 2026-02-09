# frozen_string_literal: true

module Feedkit
  # A lightweight stand-in for testing Feedkit::Schedule modules in isolation.
  # Individual tests create subclasses and include the module(s) under test.
  class ScheduleTestDummyBase
    # Provide the constants referenced by the schedule modules.
    VALID_PERIODS = Feedkit::Schedule::VALID_PERIODS
    VALID_CONDITION_TYPES = Feedkit::Schedule::VALID_CONDITION_TYPES
    CONDITION_NAME_ORDER = Feedkit::Schedule::CONDITION_NAME_ORDER

    VALID_HOUR_RANGE = Feedkit::Schedule::VALID_HOUR_RANGE
    VALID_DAY_RANGE = Feedkit::Schedule::VALID_DAY_RANGE
    VALID_WEEKDAY_RANGE = Feedkit::Schedule::VALID_WEEKDAY_RANGE
    VALID_MONTH_RANGE = Feedkit::Schedule::VALID_MONTH_RANGE

    SYMBOLIC_DAY_VALUES = Feedkit::Schedule::SYMBOLIC_DAY_VALUES
    SYMBOLIC_WEEK_VALUES = Feedkit::Schedule::SYMBOLIC_WEEK_VALUES

    WEEKDAYS = Feedkit::Schedule::WEEKDAYS
    MONTHS = Feedkit::Schedule::MONTHS

    CONDITION_ABBREVIATIONS = Feedkit::Schedule::CONDITION_ABBREVIATIONS
    PERIOD_ABBREVIATIONS = Feedkit::Schedule::PERIOD_ABBREVIATIONS
    ARRAY_VALUE_CANONICALIZERS = Feedkit::Schedule::ARRAY_VALUE_CANONICALIZERS

    attr_reader :period, :conditions, :superseded_by

    def initialize(period:, at:, as: nil, superseded_by: [])
      @period = period.to_sym
      @conditions = at
      @superseded_by = Array(superseded_by).map(&:to_s)
      @explicit_period_name = as&.to_s

      # Validation is module-provided; only run it when the module is included.
      validate_period! if respond_to?(:validate_period!, true)
      validate_conditions! if respond_to?(:validate_conditions!, true)
    end

    def period_name
      return @explicit_period_name if @explicit_period_name
      return generate_period_name if respond_to?(:generate_period_name, true)

      nil
    end

    def due?(time = Time.current)
      time = normalize_time(time)
      matches_effective_conditions?(time)
    end

    def period_start_at(time = Time.current)
      time = normalize_time(time)
      Feedkit::Schedule::PeriodStartCalculator.new(schedule: self, time:, unit: period).call
    end

    def effective_conditions
      @effective_conditions ||= implicit_conditions_for_period.merge(conditions)
    end

    private

    def normalize_time(time)
      time.respond_to?(:in_time_zone) ? time.in_time_zone : time
    end

    # Reproduce the Schedule class' implicit defaults so modules can be tested
    # without depending on Feedkit::Schedule itself.
    def matches_effective_conditions?(time)
      effective_conditions.all? { |type, value| matches?(type, value, time) }
    end

    def implicit_conditions_for_period
      implicit_hour_conditions.merge(implicit_date_conditions)
    end

    def implicit_hour_conditions
      return {} if conditions.is_a?(Hash) && (conditions.key?(:hour) || period == :hour)

      { hour: 0 }
    end

    def implicit_date_conditions
      return implicit_weekday_conditions if period == :week
      return implicit_month_day_conditions if period == :month
      return implicit_year_conditions if period == :year

      {}
    end

    def implicit_weekday_conditions
      conditions.is_a?(Hash) && conditions.key?(:weekday) ? {} : { weekday: :monday }
    end

    def implicit_month_day_conditions
      conditions.is_a?(Hash) && conditions.key?(:day) ? {} : { day: 1 }
    end

    def implicit_year_conditions
      implicit = {}
      implicit[:month] = :january unless conditions.is_a?(Hash) && conditions.key?(:month)
      implicit[:day] = 1 unless conditions.is_a?(Hash) && conditions.key?(:day)
      implicit
    end
  end
end
