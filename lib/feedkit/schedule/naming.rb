# frozen_string_literal: true

module Feedkit
  class Schedule
    module Naming
      private

      def generate_period_name
        parts = [period_abbreviation]
        ordered_conditions_for_name.each do |type, value|
          parts << "#{condition_abbreviation(type)}#{condition_value(type, value)}"
        end
        parts.join("_")
      end

      def period_abbreviation
        PERIOD_ABBREVIATIONS.fetch(period)
      end

      def ordered_conditions_for_name
        # Keep generated names based on explicitly provided conditions only.
        # Defaults affect behavior, but including them in auto-names tends to be noisy.
        conditions.sort_by { |type, _| CONDITION_NAME_ORDER.index(type) || CONDITION_NAME_ORDER.length }
                  .map { |type, value| [type, canonicalize_condition_value_for_name(type, value)] }
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

      def canonicalize_condition_value_for_name(type, value)
        normalized = normalize_condition_value(type, value)
        return canonicalize_array_value_for_name(type, normalized) if normalized.is_a?(Array)

        normalized
      end

      def canonicalize_array_value_for_name(type, values)
        method_name = ARRAY_VALUE_CANONICALIZERS[type]
        return values unless method_name

        send(method_name, values)
      end

      def canonicalize_hour_array(values)
        values.map(&:to_i).uniq.sort
      end

      def canonicalize_day_array(values)
        values.uniq.sort_by do |v|
          if v == :first
            -1
          elsif v == :last
            99_999
          else
            v.to_i
          end
        end
      end

      def canonicalize_weekday_array(values)
        values.map { |v| normalize_weekday(v).to_i }.uniq.sort
      end

      def canonicalize_month_array(values)
        values.map { |v| normalize_month(v).to_i }.uniq.sort
      end
    end
  end
end
