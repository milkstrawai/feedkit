# frozen_string_literal: true

module Feedkit
  class Engine < ::Rails::Engine
    isolate_namespace Feedkit

    config.generators do |g|
      g.test_framework :minitest, fixture: false
    end

    initializer "feedkit.set_configs" do
      Feedkit.configuration.logger ||= Rails.logger
    end
  end
end
