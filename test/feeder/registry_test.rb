# frozen_string_literal: true

require "test_helper"

module Feeder
  class RegistryTest < ActiveSupport::TestCase
    class ScheduledGenerator < Feeder::Generator
      owned_by Organization

      schedule every: 1.week, at: { hour: 7, weekday: :monday }, as: :weekly

      private

      def data
        { scheduled: true }
      end
    end

    class UnscheduledGenerator < Feeder::Generator
      owned_by Organization

      private

      def data
        { unscheduled: true }
      end
    end

    class OwnerlessGenerator < Feeder::Generator
      private

      def data
        { ownerless: true }
      end
    end

    class ScheduledOwnerlessGenerator < Feeder::Generator
      schedule every: 1.week, at: { hour: 7, weekday: :monday }, as: :weekly

      private

      def data
        { scheduled_ownerless: true }
      end
    end

    setup do
      # Ensure our test generators are registered (they may have been cleared by other tests)
      Feeder::Registry.register(ScheduledGenerator)
      Feeder::Registry.register(UnscheduledGenerator)
      Feeder::Registry.register(OwnerlessGenerator)
      Feeder::Registry.register(ScheduledOwnerlessGenerator)
    end

    test "generators returns all registered generators" do
      assert_includes Feeder::Registry.generators, ScheduledGenerator
      assert_includes Feeder::Registry.generators, UnscheduledGenerator
      assert_includes Feeder::Registry.generators, OwnerlessGenerator
    end

    test "scheduled_generators returns only generators with schedules" do # rubocop:disable Minitest/MultipleAssertions
      scheduled = Feeder::Registry.scheduled_generators

      assert_includes scheduled, ScheduledGenerator
      assert_includes scheduled, ScheduledOwnerlessGenerator
      assert_not_includes scheduled, UnscheduledGenerator
      assert_not_includes scheduled, OwnerlessGenerator
    end

    test "dispatchable_generators returns only scheduled generators with an owner" do # rubocop:disable Minitest/MultipleAssertions
      dispatchable = Feeder::Registry.dispatchable_generators

      assert_includes dispatchable, ScheduledGenerator
      assert_not_includes dispatchable, ScheduledOwnerlessGenerator
      assert_not_includes dispatchable, UnscheduledGenerator
      assert_not_includes dispatchable, OwnerlessGenerator
    end

    test "generators_for_owner filters by owner class" do
      generators = Feeder::Registry.generators_for_owner(Organization)

      assert_includes generators, ScheduledGenerator
      assert_includes generators, UnscheduledGenerator
      assert_not_includes generators, OwnerlessGenerator
    end

    test "due_at returns only dispatchable generators with due schedules" do
      travel_to(Time.zone.parse("2024-10-14 07:00:00")) do # Monday 7 AM
        due = Feeder::Registry.due_at

        generators = due.map { |d| d[:generator] }

        assert_includes generators, ScheduledGenerator
        assert_not_includes generators, ScheduledOwnerlessGenerator
        assert_equal "weekly", due.find { |d| d[:generator] == ScheduledGenerator }[:period_name]
      end
    end

    test "due_at returns empty array when nothing is due" do
      # Clear and add only non-matching generators
      Feeder::Registry.clear!
      Feeder::Registry.register(UnscheduledGenerator)

      travel_to(Time.zone.parse("2024-10-15 12:00:00")) do # Tuesday noon
        due = Feeder::Registry.due_at

        assert_empty due
      end
    end

    test "register adds generator to registry" do
      klass = Class.new(Feeder::Generator)
      Feeder::Registry.register(klass)

      assert_includes Feeder::Registry.generators, klass
    end

    test "unregister removes generator from registry" do
      klass = Class.new(Feeder::Generator)
      Feeder::Registry.register(klass)
      Feeder::Registry.unregister(klass)

      assert_not_includes Feeder::Registry.generators, klass
    end

    test "clear! removes all generators" do
      Feeder::Registry.clear!

      assert_empty Feeder::Registry.generators
    end
  end
end
