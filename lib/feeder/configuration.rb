# frozen_string_literal: true

module Feeder
  class Configuration
    attr_accessor :table_name, :association_name, :generator_paths, :owner_id_type, :logger

    def initialize
      @table_name = "feeder_feeds"
      @association_name = :feeds
      @generator_paths = ["app/generators/**/*.rb"]
      @owner_id_type = :bigint
      @logger = nil
    end
  end
end
