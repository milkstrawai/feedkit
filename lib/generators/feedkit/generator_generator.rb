# frozen_string_literal: true

require "rails/generators"

module Feedkit
  module Generators
    class GeneratorGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class_option :owner,
                   type: :string,
                   default: nil,
                   desc: "The owner model class name (e.g., Organization)"

      def create_generator_file
        template "generator.rb.tt", "app/generators/#{file_name}.rb"
      end

      def create_test_file
        template "generator_test.rb.tt", "test/generators/#{file_name}_test.rb"
      end

      private

      def owner_class
        options[:owner]
      end

      def owner?
        owner_class.present?
      end
    end
  end
end
