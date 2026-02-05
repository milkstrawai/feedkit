# frozen_string_literal: true

require "active_support"

require_relative "feedkit/version"
require_relative "feedkit/configuration"
require_relative "feedkit/schedule"
require_relative "feedkit/schedulable"
require_relative "feedkit/registry"
require_relative "feedkit/generator"
require_relative "feedkit/feeds_owner"

module Feedkit
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def logger
      configuration.logger || (defined?(Rails) ? Rails.logger : Logger.new($stdout))
    end

    def eager_load_generators!
      return if @generators_loaded
      return if defined?(Rails) && Rails.application.config.eager_load

      configuration.generator_paths.each do |path|
        pattern = defined?(Rails) ? Rails.root.join(path) : path
        Dir[pattern].each { |file| require file }
      end

      @generators_loaded = true
    end

    def reset_eager_load!
      @generators_loaded = false
    end
  end
end

require_relative "feedkit/engine" if defined?(Rails::Engine)
