# frozen_string_literal: true

require "test_helper"

module Feedkit
  class DispatchJobTest < ActiveJob::TestCase
    class WeeklyGenerator < Feedkit::Generator
      owned_by Organization

      schedule every: 1.week, at: { hour: 7, weekday: :monday }, as: :weekly

      private

      def data
        { weekly: true }
      end
    end

    setup do
      @organization = Organization.create!(name: "Test Org")
      # Clear and register only our test generator
      Feedkit::Registry.clear!
      Feedkit::Registry.register(WeeklyGenerator)
    end

    teardown do
      Feedkit::Feed.delete_all
      Organization.delete_all
    end

    test "enqueues generate jobs for each owner when feeds are due" do
      travel_to(Time.zone.parse("2024-10-14 07:00:00")) do # Monday 7 AM - weekly due
        expected_jobs = Organization.count * Feedkit::Registry.due_at.count

        assert_enqueued_jobs expected_jobs, only: Feedkit::GenerateFeedJob do
          Feedkit::DispatchJob.perform_now
        end
      end
    end

    test "enqueues jobs with correct arguments" do
      travel_to(Time.zone.parse("2024-10-14 07:00:00")) do # Monday 7 AM
        Feedkit::DispatchJob.perform_now

        assert_enqueued_with(
          job: Feedkit::GenerateFeedJob,
          args: [{
            owner_id: @organization.id,
            owner_class: "Organization",
            generator_class: "Feedkit::DispatchJobTest::WeeklyGenerator",
            period_name: "weekly"
          }]
        )
      end
    end

    test "enqueues no jobs when no feeds are due" do
      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday noon - nothing due
        assert_no_enqueued_jobs only: Feedkit::GenerateFeedJob do
          Feedkit::DispatchJob.perform_now
        end
      end
    end
  end
end
