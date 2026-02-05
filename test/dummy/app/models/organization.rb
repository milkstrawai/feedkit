# frozen_string_literal: true

class Organization < ActiveRecord::Base
  include Feedkit::FeedsOwner
end
