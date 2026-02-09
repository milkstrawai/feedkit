# frozen_string_literal: true

module Feedkit
  class Schedule
    module Validation
      private

      def validate_period!
        return if VALID_PERIODS.include?(period)

        raise ArgumentError, "Unknown period: #{period}. Valid periods: #{VALID_PERIODS.join(", ")}"
      end

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
        if type == :week
          validate_week_value!(value)
          return
        end

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

        raise ArgumentError, "Invalid week value: #{value}. Must be :odd or :even"
      end

      def validate_month_value!(value)
        return if MONTHS.key?(value)
        return if value.is_a?(Integer) && VALID_MONTH_RANGE.cover?(value)

        raise ArgumentError,
              "Invalid month value: #{value}. Must be integer 1-12 or symbol (#{MONTHS.keys.join(", ")})"
      end
    end
  end
end
