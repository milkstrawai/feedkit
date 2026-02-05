# frozen_string_literal: true

require "test_helper"

module Feedkit
  class ConfigurationTest < ActiveSupport::TestCase
    test "default table_name is feedkit_feeds" do
      config = Feedkit::Configuration.new

      assert_equal "feedkit_feeds", config.table_name
    end

    test "default association_name is :feeds" do
      config = Feedkit::Configuration.new

      assert_equal :feeds, config.association_name
    end

    test "default generator_paths includes app/generators" do
      config = Feedkit::Configuration.new

      assert_includes config.generator_paths, "app/generators/**/*.rb"
    end

    test "default owner_id_type is :bigint" do
      config = Feedkit::Configuration.new

      assert_equal :bigint, config.owner_id_type
    end

    test "default logger is nil" do
      config = Feedkit::Configuration.new

      assert_nil config.logger
    end

    test "configuration values are writable" do # rubocop:disable Minitest/MultipleAssertions
      config = Feedkit::Configuration.new
      logger = Logger.new($stdout)

      config.table_name = "custom_feeds"
      config.association_name = :custom_feeds
      config.generator_paths = ["lib/generators/**/*.rb"]
      config.owner_id_type = :uuid
      config.logger = logger

      assert_equal "custom_feeds", config.table_name
      assert_equal :custom_feeds, config.association_name
      assert_equal ["lib/generators/**/*.rb"], config.generator_paths
      assert_equal :uuid, config.owner_id_type
      assert_equal logger, config.logger
    end

    test "Feedkit.logger returns custom logger when configured" do
      custom_logger = Logger.new($stdout)
      original_logger = Feedkit.configuration.logger

      Feedkit.configuration.logger = custom_logger

      assert_equal custom_logger, Feedkit.logger
    ensure
      Feedkit.configuration.logger = original_logger
    end

    test "Feedkit.logger returns Rails.logger when no custom logger" do
      assert_equal Rails.logger, Feedkit.logger
    end

    test "Feedkit.eager_load_generators! skips when already loaded" do
      Feedkit.eager_load_generators!

      # Second call should be a no-op (returns early due to @generators_loaded)
      assert_nothing_raised { Feedkit.eager_load_generators! }
    end
  end
end
