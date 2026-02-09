# frozen_string_literal: true

require "test_helper"

module Feedkit
  class RegistryTest < ActiveSupport::TestCase
    class ScheduledGenerator < Feedkit::Generator
      owned_by Organization

      every :week, at: { hour: 7, weekday: :monday }, as: :weekly

      private

      def data
        { scheduled: true }
      end
    end

    class UnscheduledGenerator < Feedkit::Generator
      owned_by Organization

      private

      def data
        { unscheduled: true }
      end
    end

    class OwnerlessGenerator < Feedkit::Generator
      private

      def data
        { ownerless: true }
      end
    end

    class ScheduledOwnerlessGenerator < Feedkit::Generator
      every :week, at: { hour: 7, weekday: :monday }, as: :weekly

      private

      def data
        { scheduled_ownerless: true }
      end
    end

    setup do
      # Ensure our test generators are registered (they may have been cleared by other tests)
      Feedkit::Registry.register(ScheduledGenerator)
      Feedkit::Registry.register(UnscheduledGenerator)
      Feedkit::Registry.register(OwnerlessGenerator)
      Feedkit::Registry.register(ScheduledOwnerlessGenerator)
    end

    teardown do
      Feedkit::Registry.clear!
    end

    test "generators returns all registered generators" do
      assert_includes Feedkit::Registry.generators, ScheduledGenerator
      assert_includes Feedkit::Registry.generators, UnscheduledGenerator
      assert_includes Feedkit::Registry.generators, OwnerlessGenerator
    end

    test "scheduled_generators returns only generators with schedules" do # rubocop:disable Minitest/MultipleAssertions
      scheduled = Feedkit::Registry.scheduled_generators

      assert_includes scheduled, ScheduledGenerator
      assert_includes scheduled, ScheduledOwnerlessGenerator
      assert_not_includes scheduled, UnscheduledGenerator
      assert_not_includes scheduled, OwnerlessGenerator
    end

    test "dispatchable_generators returns only scheduled generators with an owner" do # rubocop:disable Minitest/MultipleAssertions
      dispatchable = Feedkit::Registry.dispatchable_generators

      assert_includes dispatchable, ScheduledGenerator
      assert_not_includes dispatchable, ScheduledOwnerlessGenerator
      assert_not_includes dispatchable, UnscheduledGenerator
      assert_not_includes dispatchable, OwnerlessGenerator
    end

    test "generators_for_owner filters by owner class" do
      generators = Feedkit::Registry.generators_for_owner(Organization)

      assert_includes generators, ScheduledGenerator
      assert_includes generators, UnscheduledGenerator
      assert_not_includes generators, OwnerlessGenerator
    end

    test "due_at returns only dispatchable generators with due schedules" do
      travel_to(Time.zone.parse("2024-10-14 07:00:00")) do # Monday 7 AM
        due = Feedkit::Registry.due_at

        generators = due.map { |d| d[:generator] }

        assert_includes generators, ScheduledGenerator
        assert_not_includes generators, ScheduledOwnerlessGenerator
        assert_equal "weekly", due.find { |d| d[:generator] == ScheduledGenerator }[:period_name]
      end
    end

    test "due_at returns empty array when nothing is due" do
      # Clear and add only non-matching generators
      Feedkit::Registry.clear!
      Feedkit::Registry.register(UnscheduledGenerator)

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday noon
        due = Feedkit::Registry.due_at

        assert_empty due
      end
    end

    test "register adds generator to registry" do
      klass = Class.new(Feedkit::Generator)
      Feedkit::Registry.register(klass)

      assert_includes Feedkit::Registry.generators, klass
    end

    test "unregister removes generator from registry" do
      klass = Class.new(Feedkit::Generator)
      Feedkit::Registry.register(klass)
      Feedkit::Registry.unregister(klass)

      assert_not_includes Feedkit::Registry.generators, klass
    end

    test "clear! removes all generators" do
      Feedkit::Registry.clear!

      assert_empty Feedkit::Registry.generators
    end
  end
end
