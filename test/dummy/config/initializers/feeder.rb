# frozen_string_literal: true

Feeder.configure do |config|
  config.table_name = "feeder_feeds"
  config.association_name = :feeds
  config.generator_paths = ["test/dummy/app/generators/**/*.rb"]
  config.owner_id_type = :bigint
end
