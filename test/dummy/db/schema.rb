# frozen_string_literal: true

ActiveRecord::Schema.define(version: 1) do
  create_table :organizations, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :feedkit_feeds, force: true do |t|
    t.string :owner_type
    t.bigint :owner_id
    t.string :feed_type, null: false
    t.string :period_name
    t.datetime :period_start_at
    t.json :data, null: false, default: {}
    t.timestamps
  end

  add_index :feedkit_feeds, :created_at
  add_index :feedkit_feeds, %i[owner_type owner_id feed_type created_at], name: "idx_feedkit_feeds_lookup"
  add_index :feedkit_feeds, %i[owner_type owner_id feed_type period_name period_start_at],
            name: "idx_feedkit_feeds_dedup", unique: true
end
