# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module Feedkit
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :owner_id_type,
                   type: :string,
                   default: "bigint",
                   desc: "The type for owner_id column (bigint or uuid)"

      def self.next_migration_number(dirname)
        if ActiveRecord::Base.timestamped_migrations
          Time.now.utc.strftime("%Y%m%d%H%M%S")
        else
          format("%<number>.3d", number: (current_migration_number(dirname) + 1))
        end
      end

      def create_initializer
        template "initializer.rb.tt", "config/initializers/feedkit.rb"
      end

      def create_migration
        migration_template "migration.rb.tt", "db/migrate/create_feedkit_feeds.rb"
      end

      def create_generators_directory
        empty_directory "app/generators"
        create_file "app/generators/.keep"
      end

      private

      def owner_id_type
        options[:owner_id_type]
      end
    end
  end
end
