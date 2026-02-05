# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "/test/"
  add_group "Core", "lib/feedkit"
  add_group "Generators", "lib/generators"
  add_group "Models", "app/models"
  add_group "Jobs", "app/jobs"

  enable_coverage :branch
  minimum_coverage line: 100, branch: 90
end

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "mocha/minitest"

ActiveRecord::Migration.maintain_test_schema!

# Load the schema
ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

module ActiveSupport
  class TestCase
    # Reset eager load state after each test
    teardown do
      Feedkit.reset_eager_load!
    end
  end
end
