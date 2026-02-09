# frozen_string_literal: true

module Feedkit
  class Schedule
    module Normalization
      private

      def normalize_day_value_list(value, time)
        return normalize_range(:day, value, time).to_a if value.is_a?(Range)
        return value.flat_map { |v| normalize_day_value_list(v, time) } if value.is_a?(Array)
        return [normalize_day_endpoint(value, time)] if value.is_a?(Symbol)

        [value.to_i]
      end

      def normalize_weekday_value_list(value)
        value = normalize_weekday(value)
        case value
        when Range then value.to_a
        when Array then value
        else [value]
        end
      end

      def normalize_month_value_list(value)
        value = normalize_month(value)
        case value
        when Range then value.to_a
        when Array then value
        else [value]
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

      def normalize_range(type, range, time)
        return range unless type == :day

        begin_value = normalize_day_endpoint(range.begin, time)
        end_value = normalize_day_endpoint(range.end, time)

        range.exclude_end? ? (begin_value...end_value) : (begin_value..end_value)
      end

      def normalize_day_endpoint(value, time)
        case value
        when :first then 1
        when :last then time.end_of_month.day
        else value
        end
      end
    end
  end
end
