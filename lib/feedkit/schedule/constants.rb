# frozen_string_literal: true

module Feedkit
  class Schedule
    VALID_PERIODS = %i[hour day week month year].freeze
    VALID_CONDITION_TYPES = %i[hour day weekday week month].freeze
    CONDITION_NAME_ORDER = %i[hour day weekday week month].freeze

    VALID_HOUR_RANGE = (0..23)
    VALID_DAY_RANGE = (1..31)
    VALID_WEEKDAY_RANGE = (0..6)
    VALID_MONTH_RANGE = (1..12)

    SYMBOLIC_DAY_VALUES = %i[first last].freeze
    SYMBOLIC_WEEK_VALUES = %i[odd even].freeze

    WEEKDAYS = {
      sunday: 0,
      monday: 1,
      tuesday: 2,
      wednesday: 3,
      thursday: 4,
      friday: 5,
      saturday: 6
    }.freeze

    MONTHS = {
      january: 1,
      february: 2,
      march: 3,
      april: 4,
      may: 5,
      june: 6,
      july: 7,
      august: 8,
      september: 9,
      october: 10,
      november: 11,
      december: 12
    }.freeze

    CONDITION_ABBREVIATIONS = {
      hour: "h",
      day: "d",
      weekday: "wd",
      week: "wk",
      month: "m"
    }.freeze

    PERIOD_ABBREVIATIONS = {
      hour: "h1",
      day: "d1",
      week: "w1",
      month: "m1",
      year: "y1"
    }.freeze

    ARRAY_VALUE_CANONICALIZERS = {
      hour: :canonicalize_hour_array,
      day: :canonicalize_day_array,
      weekday: :canonicalize_weekday_array,
      month: :canonicalize_month_array
    }.freeze
  end
end
