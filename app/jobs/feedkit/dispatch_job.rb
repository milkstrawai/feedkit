# frozen_string_literal: true

module Feedkit
  class DispatchJob < ActiveJob::Base
    queue_as :default

    def perform
      time = Time.current
      due_feeds = Feedkit::Registry.due_at(time)

      Feedkit.logger.info "[Feedkit::DispatchJob] Found #{due_feeds.count} feeds due at #{time}"

      due_feeds.each do |config|
        config[:generator].owner_class.find_each do |owner|
          enqueue_feed_job(owner, config[:generator], config[:period_name])
        end
      end
    end

    private

    def enqueue_feed_job(owner, generator, period_name)
      Feedkit::GenerateFeedJob.perform_later(
        owner_id: owner.id,
        owner_class: owner.class.name,
        generator_class: generator.name,
        period_name: period_name
      )
    end
  end
end
