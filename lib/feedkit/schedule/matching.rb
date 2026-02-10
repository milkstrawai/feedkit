# frozen_string_literal: true

module Feedkit
  class Schedule
    module Matching
      private

      def matches?(type, value, time)
        actual = actual_value_for(type, time)
        value = normalize_condition_value(type, value)

        matches_condition_value?(type, value, actual, time)
      end

      def actual_value_for(type, time)
        case type
        when :hour    then time.hour
        when :day     then time.day
        when :weekday then time.to_date.cwday
        when :week    then time.to_date.cweek
        when :month   then time.month
        end
      end

      def normalize_condition_value(type, value)
        case type
        when :weekday then normalize_weekday(value)
        when :month then normalize_month(value)
        else value
        end
      end

      def matches_condition_value?(type, value, actual, time)
        case value
        when Range then normalize_range(type, value, time).cover?(actual)
        when Array then value.any? { |v| scalar_matches?(type, v, actual, time) }
        when Symbol then symbolic_match?(value, type, time)
        else value == actual
        end
      end

      def scalar_matches?(type, value, actual, time)
        return symbolic_match?(value, type, time) if value.is_a?(Symbol)

        value == actual
      end

      def symbolic_match?(value, type, time)
        case [type, value]
        when %i[day first] then time.day == 1
        when %i[day last]  then time.day == time.end_of_month.day
        when %i[week odd]  then time.to_date.cweek.odd?
        when %i[week even] then time.to_date.cweek.even?
        end
      end
    end
  end
end
