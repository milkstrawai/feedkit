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

      def feed_type
        name.demodulize.underscore.to_sym
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

    def call
      return if already_generated?
      return unless (payload = data)

      create_feed!(payload)
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

    def already_generated?
      return false unless @schedule
      return false unless @owner

      feed_scope.where(feed_type: self.class.feed_type, period_name: period_name)
                .exists?(["created_at > ?", period.ago])
    end

    def create_feed!(payload)
      if @owner
        feed_scope.create!(feed_type: self.class.feed_type, period_name: period_name, data: payload)
      else
        Feedkit::Feed.create!(feed_type: self.class.feed_type, period_name: period_name, data: payload)
      end
    end

    def feed_scope
      @owner.public_send(Feedkit.configuration.association_name)
    end
  end
end
