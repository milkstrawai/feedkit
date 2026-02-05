# frozen_string_literal: true

require "active_support/concern"

module Feedkit
  module Schedulable
    extend ActiveSupport::Concern

    class_methods do
      def schedules
        @schedules ||= []
      end

      def schedule(every:, at:, as: nil, superseded_by: [])
        schedules << Feedkit::Schedule.new(every: every, at: at, as: as, superseded_by: superseded_by)
      end

      def schedules_due(time = Time.current)
        due = schedules.select { |s| s.due?(time) }
        due_names = due.map(&:period_name)
        due.reject { |s| s.superseded_by.any? { |name| due_names.include?(name) } }
      end

      def find_schedule(period_name)
        schedules.find { |s| s.period_name == period_name&.to_s }
      end
    end
  end
end
