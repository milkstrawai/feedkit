# frozen_string_literal: true

require "test_helper"

module Feedkit
  class GenerateFeedJobTest < ActiveJob::TestCase
    class TestGenerator < Feedkit::Generator
      owned_by Organization

      every :week, at: { hour: 7, weekday: :monday }, as: :weekly

      private

      def data
        { test: true }
      end
    end

    setup do
      @organization = Organization.create!(name: "Test Org")
    end

    teardown do
      Feedkit::Feed.delete_all
      Organization.delete_all
    end

    test "creates feed for owner" do # rubocop:disable Minitest/MultipleAssertions
      assert_difference "Feedkit::Feed.count", 1 do
        Feedkit::GenerateFeedJob.perform_now(
          owner_id: @organization.id,
          owner_class: "Organization",
          generator_class: "Feedkit::GenerateFeedJobTest::TestGenerator",
          period_name: "weekly",
          scheduled_at: Time.zone.parse("2024-10-14 07:00:00")
        )
      end

      feed = Feedkit::Feed.last

      assert_equal @organization, feed.owner
      assert_equal "test_generator", feed.feed_type
      assert_equal "weekly", feed.period_name
    end

    test "silently skips when owner is deleted" do
      assert_nothing_raised do
        Feedkit::GenerateFeedJob.perform_now(
          owner_id: -1,
          owner_class: "Organization",
          generator_class: "Feedkit::GenerateFeedJobTest::TestGenerator",
          period_name: "weekly",
          scheduled_at: Time.zone.parse("2024-10-14 07:00:00")
        )
      end
    end

    test "logs errors without raising" do
      TestGenerator.any_instance.stubs(:call).raises(StandardError, "Test error")

      assert_nothing_raised do
        Feedkit::GenerateFeedJob.perform_now(
          owner_id: @organization.id,
          owner_class: "Organization",
          generator_class: "Feedkit::GenerateFeedJobTest::TestGenerator",
          period_name: "weekly",
          scheduled_at: Time.zone.parse("2024-10-14 07:00:00")
        )
      end
    end
  end
end
