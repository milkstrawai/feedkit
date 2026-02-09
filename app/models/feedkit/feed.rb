# frozen_string_literal: true

module Feedkit
  class Feed < ActiveRecord::Base
    self.table_name = Feedkit.configuration.table_name

    belongs_to :owner, polymorphic: true, optional: true

    validates :feed_type, presence: true
    validates :data, presence: true, unless: -> { data == {} }

    scope :for_owner, ->(owner) { where(owner:) }
    scope :latest, -> { order(created_at: :desc) }
    scope :by_type, ->(type) { where(feed_type: type) }
    scope :recent, ->(limit = 50) { latest.limit(limit) }
  end
end
