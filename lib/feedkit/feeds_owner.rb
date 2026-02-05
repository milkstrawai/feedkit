# frozen_string_literal: true

require "active_support/concern"

module Feedkit
  module FeedsOwner
    extend ActiveSupport::Concern

    included do
      has_many Feedkit.configuration.association_name,
               class_name: "Feedkit::Feed",
               as: :owner,
               dependent: :delete_all
    end
  end
end
