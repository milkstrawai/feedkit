# frozen_string_literal: true

module Feedkit
  class Generator
    include Schedulable

    class << self
      def inherited(subclass)
        super

        Feedkit::Registry.register(subclass)
      end

      def owned_by(type = nil)
        @owner_class = type || @owner_class
      end

      def owner_class
        return @owner_class.constantize if @owner_class.is_a?(String)

        @owner_class
      end

      def feed_type(value = nil)
        @feed_type = value.to_sym if value

        @feed_type || default_feed_type
      end

      def default_feed_type
        name.underscore.tr("/", "_").to_sym
      end

      def scheduled?
        schedules.any?
      end
    end

    def initialize(owner = nil, period_name: nil, **options)
      @owner = owner
      @options = options
      @schedule = period_name ? self.class.find_schedule(period_name) : nil

      raise ArgumentError, "Unknown schedule: #{period_name}" if period_name && !@schedule
    end

    def call(run_at: Time.current)
      period_start = period_start_at(run_at)
      return if already_generated?(period_start)
      return unless (payload = data)

      create_feed!(payload, period_start)
    end

    private

    attr_reader :owner, :options

    def data
      raise NotImplementedError, "#{self.class.name} must implement #data"
    end

    def period
      @schedule&.period
    end

    def period_name
      @schedule&.period_name
    end

    def period_start_at(run_at)
      @schedule&.period_start_at(run_at)
    end

    def already_generated?(period_start)
      return false unless @schedule
      return false unless @owner

      feed_scope.where(feed_type: self.class.feed_type, period_name:)
                .exists?(period_start_at: period_start)
    end

    def create_feed!(payload, period_start)
      attrs = { feed_type: self.class.feed_type, period_name:, data: payload }
      attrs[:period_start_at] = period_start if @schedule

      if @owner
        feed_scope.create!(attrs)
      else
        Feedkit::Feed.create!(attrs)
      end
    rescue ActiveRecord::RecordNotUnique
      # Concurrency-safe dedup: another worker created this feed for the same
      # (owner, feed_type, period_name, period_start_at) after our check.
      nil
    end

    def feed_scope
      @owner.public_send(Feedkit.configuration.association_name)
    end
  end
end
