# frozen_string_literal: true

require "active_support/concern"

module Feeder
  module FeedsOwner
    extend ActiveSupport::Concern

    included do
      has_many Feeder.configuration.association_name,
               class_name: "Feeder::Feed",
               as: :owner,
               dependent: :delete_all
    end
  end
end
