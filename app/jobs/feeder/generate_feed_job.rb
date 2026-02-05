# frozen_string_literal: true

module Feeder
  class GenerateFeedJob < ActiveJob::Base
    queue_as :default

    def perform(owner_id:, owner_class:, generator_class:, period_name:)
      owner = owner_class.constantize.find(owner_id)
      generator = generator_class.constantize

      generator.new(owner, period_name: period_name).call
    rescue ActiveRecord::RecordNotFound
      # Owner deleted between dispatch and execution - skip silently
    rescue StandardError => e
      Feeder.logger.error "[Feeder] Failed: #{generator_class} for #{owner_class}##{owner_id}"
      Feeder.logger.error e.full_message
    end
  end
end
