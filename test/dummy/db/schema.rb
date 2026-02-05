# frozen_string_literal: true

ActiveRecord::Schema.define(version: 1) do
  create_table :organizations, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :feeder_feeds, force: true do |t|
    t.string :owner_type
    t.bigint :owner_id
    t.string :feed_type, null: false
    t.string :period_name
    t.json :data, null: false, default: {}
    t.timestamps
  end

  add_index :feeder_feeds, :created_at
  add_index :feeder_feeds, %i[owner_type owner_id feed_type created_at], name: "idx_feeder_feeds_lookup"
  add_index :feeder_feeds, %i[owner_type owner_id feed_type period_name], name: "idx_feeder_feeds_dedup"
end
