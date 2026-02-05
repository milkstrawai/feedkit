# frozen_string_literal: true

module Feeder
  class Schedule # rubocop:disable Metrics/ClassLength
    VALID_CONDITION_TYPES = %i[hour day weekday week month].freeze
    VALID_HOUR_RANGE = (0..23)
    VALID_DAY_RANGE = (1..31)
    VALID_WEEKDAY_RANGE = (0..6)
    VALID_WEEK_RANGE = (1..53)
    VALID_MONTH_RANGE = (1..12)
    SYMBOLIC_DAY_VALUES = %i[first last].freeze
    SYMBOLIC_WEEK_VALUES = %i[even odd].freeze

    WEEKDAYS = {
      sunday: 0,
      monday: 1,
      tuesday: 2,
      wednesday: 3,
      thursday: 4,
      friday: 5,
      saturday: 6
    }.freeze

    MONTHS = {
      january: 1,
      february: 2,
      march: 3,
      april: 4,
      may: 5,
      june: 6,
      july: 7,
      august: 8,
      september: 9,
      october: 10,
      november: 11,
      december: 12
    }.freeze

    CONDITION_ABBREVIATIONS = {
      hour: "h",
      day: "d",
      weekday: "wd",
      week: "w",
      month: "m"
    }.freeze

    attr_reader :period_name, :period, :conditions, :superseded_by

    def initialize(every:, at:, as: nil, superseded_by: [])
      @period = every
      @conditions = at
      @superseded_by = Array(superseded_by).map(&:to_s)

      validate_conditions!

      @period_name = (as || generate_period_name).to_s
    end

    def due?(time = Time.current)
      conditions.all? { |type, value| matches?(type, value, time) }
    end

    private

    def validate_conditions!
      raise ArgumentError, "conditions must be a Hash" unless conditions.is_a?(Hash)

      conditions.each { |type, value| validate_condition!(type, value) }
    end

    def validate_condition!(type, value)
      unless VALID_CONDITION_TYPES.include?(type)
        raise ArgumentError, "Unknown condition type: #{type}. Valid types: #{VALID_CONDITION_TYPES.join(", ")}"
      end

      validate_condition_value!(type, value)
    end

    def validate_condition_value!(type, value)
      case value
      when Range then validate_range_value!(type, value)
      when Array then value.each { |v| validate_scalar_value!(type, v) }
      else validate_scalar_value!(type, value)
      end
    end

    def validate_range_value!(type, range)
      validate_scalar_value!(type, range.begin)
      validate_scalar_value!(type, range.end)
    end

    def validate_scalar_value!(type, value)
      case type
      when :hour    then validate_hour_value!(value)
      when :day     then validate_day_value!(value)
      when :weekday then validate_weekday_value!(value)
      when :week    then validate_week_value!(value)
      when :month   then validate_month_value!(value)
      end
    end

    def validate_hour_value!(value)
      return if value.is_a?(Integer) && VALID_HOUR_RANGE.cover?(value)

      raise ArgumentError, "Invalid hour value: #{value}. Must be integer 0-23"
    end

    def validate_day_value!(value)
      return if SYMBOLIC_DAY_VALUES.include?(value)
      return if value.is_a?(Integer) && VALID_DAY_RANGE.cover?(value)

      raise ArgumentError, "Invalid day value: #{value}. Must be integer 1-31 or :first/:last"
    end

    def validate_weekday_value!(value)
      return if WEEKDAYS.key?(value)
      return if value.is_a?(Integer) && VALID_WEEKDAY_RANGE.cover?(value)

      raise ArgumentError,
            "Invalid weekday value: #{value}. Must be integer 0-6 or symbol (#{WEEKDAYS.keys.join(", ")})"
    end

    def validate_week_value!(value)
      return if SYMBOLIC_WEEK_VALUES.include?(value)
      return if value.is_a?(Integer) && VALID_WEEK_RANGE.cover?(value)

      raise ArgumentError, "Invalid week value: #{value}. Must be integer 1-53 or :even/:odd"
    end

    def validate_month_value!(value)
      return if MONTHS.key?(value)
      return if value.is_a?(Integer) && VALID_MONTH_RANGE.cover?(value)

      raise ArgumentError, "Invalid month value: #{value}. Must be integer 1-12 or symbol (#{MONTHS.keys.join(", ")})"
    end

    def matches?(type, value, time)
      actual = actual_value_for(type, time)
      value = normalize_weekday(value) if type == :weekday
      value = normalize_month(value) if type == :month

      case value
      when Range  then value.cover?(actual)
      when Array  then value.include?(actual)
      when Symbol then symbolic_match?(value, type, time)
      else value == actual
      end
    end

    def actual_value_for(type, time)
      case type
      when :hour    then time.hour
      when :day     then time.day
      when :weekday then time.wday
      when :week    then time.to_date.cweek
      when :month   then time.month
      end
    end

    def symbolic_match?(value, type, time)
      case [type, value]
      when %i[day last]  then time.day == time.end_of_month.day
      when %i[day first] then time.day == 1
      when %i[week even] then time.to_date.cweek.even?
      when %i[week odd]  then time.to_date.cweek.odd?
      end
    end

    def generate_period_name
      parts = [period_abbreviation]
      conditions.each do |type, value|
        parts << "#{condition_abbreviation(type)}#{condition_value(type, value)}"
      end
      parts.join("_")
    end

    def period_abbreviation
      case period
      when 1.hour  then "h1"
      when 1.day   then "d1"
      when 1.week  then "w1"
      when 2.weeks then "w2"
      when 1.month then "m1"
      when 1.year  then "y1"
      else "s#{period.to_i}"
      end
    end

    def condition_abbreviation(type)
      CONDITION_ABBREVIATIONS[type]
    end

    def condition_value(type, value)
      value = normalize_weekday(value) if type == :weekday
      value = normalize_month(value) if type == :month

      case value
      when Range then "#{value.begin}-#{value.end}"
      when Array then value.join("-")
      else value
      end
    end

    def normalize_weekday(value)
      case value
      when Symbol then WEEKDAYS.fetch(value, value)
      when Range  then normalize_weekday(value.begin)..normalize_weekday(value.end)
      when Array  then value.map { |v| normalize_weekday(v) }
      else value
      end
    end

    def normalize_month(value)
      case value
      when Symbol then MONTHS.fetch(value, value)
      when Range  then normalize_month(value.begin)..normalize_month(value.end)
      when Array  then value.map { |v| normalize_month(v) }
      else value
      end
    end
  end
end
