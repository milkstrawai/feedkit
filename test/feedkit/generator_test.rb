# frozen_string_literal: true

require "test_helper"

module Feedkit
  class GeneratorTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
    class TestGenerator < Feedkit::Generator
      owned_by Organization

      every :day, at: { hour: 6 }

      private

      def data
        { test: "data" }
      end
    end

    class NilDataGenerator < Feedkit::Generator
      owned_by Organization

      every :day, at: { hour: 6 }

      private

      def data
        nil
      end
    end

    class StringOwnerGenerator < Feedkit::Generator
      owned_by "Organization"

      private

      def data
        {}
      end
    end

    class OwnerlessGenerator < Feedkit::Generator
      # No owned_by declaration
      # No schedules

      private

      def data
        { ownerless: true }
      end
    end

    setup do
      @registry_snapshot = Feedkit::Registry.generators.dup
      @organization = Organization.create!(name: "Test Org")
      # Ensure our test generators are registered
      Feedkit::Registry.register(TestGenerator)
      Feedkit::Registry.register(NilDataGenerator)
      Feedkit::Registry.register(StringOwnerGenerator)
      Feedkit::Registry.register(OwnerlessGenerator)
    end

    teardown do
      Feedkit::Feed.delete_all
      Organization.delete_all

      # Avoid leaking test generator classes into other tests via the global registry.
      Feedkit::Registry.clear!
      @registry_snapshot.each { |klass| Feedkit::Registry.register(klass) }
    end

    # Class methods
    test "owner_class returns the configured owner type" do
      assert_equal Organization, TestGenerator.owner_class
    end

    test "owner_class constantizes string owner type" do
      assert_equal Organization, StringOwnerGenerator.owner_class
    end

    test "owner_class returns nil for ownerless generators" do
      assert_nil OwnerlessGenerator.owner_class
    end

    test "feed_type returns underscored class name" do
      assert_equal :test_generator, TestGenerator.feed_type
    end

    test "scheduled? returns true when schedules are defined" do
      assert_predicate TestGenerator, :scheduled?
    end

    test "scheduled? returns false when no schedules are defined" do
      assert_not OwnerlessGenerator.scheduled?
    end

    # Auto-registration
    test "generators are auto-registered when defined" do
      # Define a new class to test auto-registration
      new_generator = Class.new(Feedkit::Generator) do
        def data
          {}
        end
      end

      assert_includes Feedkit::Registry.generators, new_generator
    end

    # Initialization
    test "initializes with owner" do
      generator = TestGenerator.new(@organization)

      assert_nothing_raised { generator }
    end

    test "initializes with valid period_name" do
      generator = TestGenerator.new(@organization, period_name: :d1_h6)

      assert_nothing_raised { generator }
    end

    test "raises ArgumentError for unknown period_name" do
      assert_raises ArgumentError do
        TestGenerator.new(@organization, period_name: :unknown)
      end
    end

    test "initializes ownerless generator with nil" do
      generator = OwnerlessGenerator.new(nil)

      assert_nothing_raised { generator }
    end

    # Feed generation
    test "call creates a feed" do # rubocop:disable Minitest/MultipleAssertions
      generator = TestGenerator.new(@organization, period_name: :d1_h6)

      assert_difference "Feedkit::Feed.count", 1 do
        generator.call
      end

      feed = Feedkit::Feed.last

      assert_equal @organization, feed.owner
      assert_equal "test_generator", feed.feed_type
      assert_equal "d1_h6", feed.period_name
      assert_equal({ "test" => "data" }, feed.data)
    end

    test "call skips when data returns nil" do
      generator = NilDataGenerator.new(@organization, period_name: :d1_h6)

      assert_no_difference "Feedkit::Feed.count" do
        generator.call
      end
    end

    test "call skips when already generated in current period" do
      generator = TestGenerator.new(@organization, period_name: :d1_h6)

      travel_to(Time.zone.parse("2024-10-15 06:00:00")) do
        generator.call # First call creates feed
      end

      travel_to(Time.zone.parse("2024-10-15 06:30:00")) do
        assert_no_difference "Feedkit::Feed.count" do
          TestGenerator.new(@organization, period_name: :d1_h6).call
        end
      end
    end

    test "deduplication uses schedule boundaries (not a sliding window)" do
      travel_to(Time.zone.parse("2024-10-15 06:30:00")) do
        TestGenerator.new(@organization, period_name: :d1_h6).call
      end

      travel_to(Time.zone.parse("2024-10-16 06:00:00")) do
        assert_difference "Feedkit::Feed.count", 1 do
          TestGenerator.new(@organization, period_name: :d1_h6).call
        end
      end
    end

    test "stores period_start_at at the schedule boundary" do
      travel_to(Time.zone.parse("2024-10-15 06:30:00")) do
        TestGenerator.new(@organization, period_name: :d1_h6).call
      end

      feed = Feedkit::Feed.last

      assert_equal Time.zone.parse("2024-10-15 06:00:00"), feed.period_start_at
    end

    test "call respects an explicit run_at timestamp" do
      run_at = Time.zone.parse("2024-10-15 06:30:00")

      TestGenerator.new(@organization, period_name: :d1_h6).call(run_at: run_at)

      assert_equal Time.zone.parse("2024-10-15 06:00:00"), Feedkit::Feed.last.period_start_at
    end

    test "call creates feed in new period" do
      generator = TestGenerator.new(@organization, period_name: :d1_h6)

      travel_to(Time.zone.parse("2024-10-15 06:00:00")) do
        generator.call
      end

      travel_to(Time.zone.parse("2024-10-16 06:00:00")) do
        assert_difference "Feedkit::Feed.count", 1 do
          TestGenerator.new(@organization, period_name: :d1_h6).call
        end
      end
    end

    test "call without schedule always creates feed" do
      generator = TestGenerator.new(@organization)

      assert_difference "Feedkit::Feed.count", 2 do
        generator.call
        TestGenerator.new(@organization).call
      end
    end

    test "ad-hoc call does not set period_start_at" do
      TestGenerator.new(@organization).call

      assert_nil Feedkit::Feed.last.period_start_at
    end

    # Ownerless generator
    test "ownerless generator creates feed without owner" do # rubocop:disable Minitest/MultipleAssertions
      generator = OwnerlessGenerator.new(nil)

      assert_difference "Feedkit::Feed.count", 1 do
        generator.call
      end

      feed = Feedkit::Feed.last

      assert_nil feed.owner
      assert_equal "ownerless_generator", feed.feed_type
      assert_equal({ "ownerless" => true }, feed.data)
    end

    test "ownerless generator always creates feed (no deduplication)" do
      assert_difference "Feedkit::Feed.count", 2 do
        OwnerlessGenerator.new(nil).call
        OwnerlessGenerator.new(nil).call
      end
    end

    # Private method coverage
    test "period returns nil without schedule" do
      generator = TestGenerator.new(@organization)

      assert_nil generator.send(:period)
    end

    test "period returns schedule period with schedule" do
      generator = TestGenerator.new(@organization, period_name: :d1_h6)

      assert_equal :day, generator.send(:period)
    end

    test "base generator raises NotImplementedError for #data" do
      generator = Feedkit::Generator.new(nil)

      assert_raises NotImplementedError do
        generator.call
      end
    end

    test "scheduled generator with nil owner skips deduplication" do
      # A scheduled generator initialized with a nil owner should not check for duplicates
      generator = TestGenerator.new(nil, period_name: :d1_h6)

      assert_difference "Feedkit::Feed.count", 1 do
        generator.call
      end
    end

    test "scheduled generator treats RecordNotUnique as a normal dedup skip" do
      generator = TestGenerator.new(@organization, period_name: :d1_h6)
      period_start = Time.zone.parse("2024-10-15 06:00:00")

      fake_scope = Object.new
      def fake_scope.create!(*)
        raise ActiveRecord::RecordNotUnique, "duplicate"
      end

      generator.stubs(:feed_scope).returns(fake_scope)

      assert_nothing_raised do
        generator.send(:create_feed!, { test: "data" }, period_start)
      end
    end
  end
end
