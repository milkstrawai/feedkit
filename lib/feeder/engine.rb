# frozen_string_literal: true

module Feeder
  class Engine < ::Rails::Engine
    isolate_namespace Feeder

    config.generators do |g|
      g.test_framework :minitest, fixture: false
    end

    initializer "feeder.set_configs" do
      Feeder.configuration.logger ||= Rails.logger
    end
  end
end
