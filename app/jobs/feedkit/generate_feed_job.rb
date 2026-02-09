# frozen_string_literal: true

module Feedkit
  class GenerateFeedJob < ActiveJob::Base
    queue_as :default

    def perform(owner_id:, owner_class:, generator_class:, period_name:, scheduled_at: Time.current)
      owner = owner_class.constantize.find(owner_id)
      generator = generator_class.constantize

      generator.new(owner, period_name:).call(run_at: scheduled_at)
    rescue ActiveRecord::RecordNotFound
      # Owner deleted between dispatch and execution - skip silently
    rescue StandardError => e
      Feedkit.logger.error "[Feedkit] Failed: #{generator_class} for #{owner_class}##{owner_id}"
      Feedkit.logger.error e.full_message
    end
  end
end
