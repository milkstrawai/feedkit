# frozen_string_literal: true

require "active_support/concern"

module Feedkit
  module Schedulable
    extend ActiveSupport::Concern

    class_methods do
      def schedules
        @schedules ||= []
      end

      def every(period, at:, as: nil, superseded_by: [])
        schedule = Feedkit::Schedule.new(period:, at:, as:, superseded_by:)

        if schedules.any? { |s| s.period_name == schedule.period_name }
          raise ArgumentError,
                "Duplicate schedule name '#{schedule.period_name}' for #{name || self}. " \
                "Schedule names must be unique per generator."
        end

        schedules << schedule
      end

      def schedules_due(time = Time.current)
        due = schedules.select { |s| s.due?(time) }
        due_names = due.to_set(&:period_name)
        due.reject { |s| s.superseded_by.any? { |name| due_names.include?(name) } }
      end

      def find_schedule(period_name)
        schedules.find { |s| s.period_name == period_name&.to_s }
      end
    end
  end
end
