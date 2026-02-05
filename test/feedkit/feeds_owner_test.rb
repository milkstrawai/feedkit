# frozen_string_literal: true

require "test_helper"

module Feedkit
  class FeedsOwnerTest < ActiveSupport::TestCase
    setup do
      @organization = Organization.create!(name: "Test Org")
    end

    teardown do
      Feedkit::Feed.delete_all
      Organization.delete_all
    end

    test "includes feeds association" do
      assert_respond_to @organization, :feeds
    end

    test "feeds association returns Feedkit::Feed instances" do
      @organization.feeds.create!(feed_type: "test", data: { test: true })

      assert_instance_of Feedkit::Feed, @organization.feeds.first
    end

    test "feeds association is polymorphic" do
      feed = @organization.feeds.create!(feed_type: "test", data: { test: true })

      assert_equal "Organization", feed.owner_type
      assert_equal @organization.id, feed.owner_id
    end

    test "deleting owner deletes associated feeds" do
      @organization.feeds.create!(feed_type: "test", data: { test: true })

      assert_difference "Feedkit::Feed.count", -1 do
        @organization.destroy
      end
    end
  end
end
