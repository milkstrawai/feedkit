# frozen_string_literal: true

module Feedkit
  # Tracks all generator classes via the inherited hook in Feedkit::Generator.
  # Registration happens at class load time (boot), not during requests,
  # so thread-safety of the underlying Set is not a concern in practice.
  module Registry
    class << self
      def generators
        @generators ||= Set.new
      end

      def register(klass)
        generators << klass
      end

      def unregister(klass)
        generators.delete(klass)
      end

      def clear!
        @generators = Set.new
      end

      # Returns generators that have schedules defined.
      def scheduled_generators
        generators.select(&:scheduled?)
      end

      # Returns scheduled generators that also have an owner class.
      # Only these can be dispatched automatically, since DispatchJob
      # iterates over owner records to enqueue GenerateFeedJob.
      def dispatchable_generators
        scheduled_generators.select(&:owner_class)
      end

      def generators_for_owner(owner_class)
        generators.select { |g| g.owner_class == owner_class }
      end

      def due_at(time = Time.current)
        Feedkit.eager_load_generators!

        dispatchable_generators.flat_map do |generator|
          generator.schedules_due(time).map do |schedule|
            { generator: generator, period_name: schedule.period_name }
          end
        end
      end
    end
  end
end
