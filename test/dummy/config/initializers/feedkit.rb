# frozen_string_literal: true

Feedkit.configure do |config|
  config.table_name = "feedkit_feeds"
  config.association_name = :feeds
  config.generator_paths = ["test/dummy/app/generators/**/*.rb"]
  config.owner_id_type = :bigint
end
