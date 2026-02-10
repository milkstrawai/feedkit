# frozen_string_literal: true

class FixtureGenerator < Feedkit::Generator
  private

  def data
    { fixture: true }
  end
end
