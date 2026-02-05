# frozen_string_literal: true

require "test_helper"

module Feeder
  class FeedTest < ActiveSupport::TestCase
    setup do
      @organization = Organization.create!(name: "Test Org")
    end

    teardown do
      Feeder::Feed.delete_all
      Organization.delete_all
    end

    test "belongs to owner polymorphically" do
      feed = Feeder::Feed.create!(
        owner: @organization,
        feed_type: "test",
        data: { test: true }
      )

      assert_equal @organization, feed.owner
      assert_equal "Organization", feed.owner_type
      assert_equal @organization.id, feed.owner_id
    end

    test "validates presence of feed_type" do
      feed = Feeder::Feed.new(owner: @organization, data: { test: true })

      assert_not feed.valid?
      assert_includes feed.errors[:feed_type], "can't be blank"
    end

    test "validates presence of data unless empty hash" do
      feed = Feeder::Feed.new(owner: @organization, feed_type: "test", data: nil)

      assert_not feed.valid?
      assert_includes feed.errors[:data], "can't be blank"
    end

    test "allows empty hash as data" do
      feed = Feeder::Feed.new(owner: @organization, feed_type: "test", data: {})

      assert_predicate feed, :valid?
    end

    test "allows nil owner for ownerless feeds" do
      feed = Feeder::Feed.new(feed_type: "test", data: { test: true })

      assert_predicate feed, :valid?
    end

    # Scopes
    test "for_owner scope filters by owner" do
      feed1 = Feeder::Feed.create!(owner: @organization, feed_type: "test", data: {})
      other_org = Organization.create!(name: "Other Org")
      Feeder::Feed.create!(owner: other_org, feed_type: "test", data: {})

      assert_equal [feed1], Feeder::Feed.for_owner(@organization).to_a
    end

    test "latest scope orders by created_at desc" do
      feed1 = Feeder::Feed.create!(owner: @organization, feed_type: "test", data: {})
      feed2 = Feeder::Feed.create!(owner: @organization, feed_type: "test", data: {})

      assert_equal [feed2, feed1], Feeder::Feed.latest.to_a
    end

    test "by_type scope filters by feed_type" do
      feed1 = Feeder::Feed.create!(owner: @organization, feed_type: "type_a", data: {})
      Feeder::Feed.create!(owner: @organization, feed_type: "type_b", data: {})

      assert_equal [feed1], Feeder::Feed.by_type("type_a").to_a
    end

    test "recent scope limits and orders" do
      5.times { Feeder::Feed.create!(owner: @organization, feed_type: "test", data: {}) }

      assert_equal 3, Feeder::Feed.recent(3).count
      assert_equal Feeder::Feed.latest.first, Feeder::Feed.recent(3).first
    end
  end
end
