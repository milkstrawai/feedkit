# frozen_string_literal: true

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
  config.active_support.deprecation = :stderr
  config.active_support.test_order = :random
  config.active_job.queue_adapter = :test
end
