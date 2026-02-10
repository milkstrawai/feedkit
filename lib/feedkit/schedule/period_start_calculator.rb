# frozen_string_literal: true

require "date"
require "tzinfo"

module Feedkit
  class Schedule
    # Computes the latest scheduled "tick" at-or-before a given time.
    #
    # This is used for "once per schedule period" deduplication: we store the
    # returned timestamp as `period_start_at` in the feed record and use it in
    # the unique index.
    class PeriodStartCalculator # rubocop:disable Metrics/ClassLength
      include Feedkit::Schedule::Normalization

      MAX_WINDOWS = 600

      def initialize(schedule:, time:)
        @schedule = schedule
        @time = time
      end

      def call
        return time.beginning_of_hour if unit == :hour

        candidate = find_windowed_candidate
        return candidate if candidate

        raise ArgumentError, "No schedule occurrence found for #{unit.inspect} / #{schedule.conditions.inspect}"
      end

      private

      attr_reader :schedule, :time

      def unit
        schedule.period
      end

      def find_windowed_candidate
        cursor = time

        MAX_WINDOWS.times do
          window_start, window_end = window_bounds(cursor)
          upper_bound = time < window_end ? time : window_end - 1.second

          candidate = latest_candidate_in_window(window_start, window_end, upper_bound)
          return candidate if candidate

          cursor = window_start - 1.second
        end

        nil
      end

      def latest_candidate_in_window(window_start, window_end, upper_bound)
        candidates = tick_candidates_for_window(window_start, window_end)
        candidates.reverse_each.find { |t| t <= upper_bound }
      end

      def tick_candidates_for_window(window_start, window_end)
        dates = candidate_dates_for_window(window_start)
        dates.flat_map { |date| tick_candidates_for_date(window_start, window_end, date) }.sort
      end

      def tick_candidates_for_date(window_start, window_end, date)
        candidate_hours.filter_map do |hour|
          candidate = build_candidate_time(window_start, date, hour)
          next unless candidate
          next unless candidate >= window_start && candidate < window_end
          next unless schedule.due?(candidate)

          candidate
        end
      end

      def build_candidate_time(window_start, date, hour)
        window_start.change(
          year: date.year,
          month: date.month,
          day: date.day,
          hour:,
          min: 0,
          sec: 0
        )
      rescue TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
        # In DST transitions, some local times may not exist or may be ambiguous
        # depending on the time zone rules. If Rails can't construct a stable
        # TimeWithZone for the candidate tick, skip this candidate.
        nil
      end

      def candidate_hours
        value = schedule.effective_conditions[:hour]
        return [0] unless value

        hours = case value
                when Range then value.to_a
                when Array then value
                else [value]
                end

        hours.map(&:to_i).uniq.sort
      end

      def candidate_dates_for_window(window_start)
        case unit
        when :day   then candidate_day_dates(window_start)
        when :week  then candidate_week_dates(window_start)
        when :month then candidate_month_dates(window_start)
        when :year  then candidate_year_dates(window_start)
        end
      end

      def candidate_day_dates(window_start)
        [window_start.to_date]
      end

      def candidate_week_dates(window_start)
        week_start = window_start.to_date # Monday (ISO week start)
        candidate_weekdays.map { |wday| week_start + weekday_offset_from_monday(wday) }.uniq.sort
      end

      def candidate_month_dates(window_start)
        month_time = window_start
        candidate_days_in_month(month_time).filter_map do |day|
          safe_date(month_time.year, month_time.month, day)
        end.uniq.sort
      end

      def candidate_year_dates(window_start)
        year = window_start.year
        candidate_months.flat_map do |month|
          month_time = window_start.change(month:, day: 1)
          candidate_days_in_month(month_time).filter_map { |day| safe_date(year, month, day) }
        end.uniq.sort
      end

      def safe_date(year, month, day)
        Date.new(year, month, day)
      rescue Date::Error
        nil
      end

      def candidate_weekdays
        value = schedule.effective_conditions[:weekday]
        return [WEEKDAYS.fetch(:monday)] unless value

        normalize_weekday_value_list(value).uniq.sort
      end

      def candidate_months
        value = schedule.effective_conditions[:month]
        return [MONTHS.fetch(:january)] unless value

        normalize_month_value_list(value).uniq.sort
      end

      def candidate_days_in_month(time)
        value = schedule.effective_conditions[:day]
        return [1] unless value

        normalize_day_value_list(value, time).uniq.sort
      end

      def weekday_offset_from_monday(wday)
        (wday.to_i - 1) % 7
      end

      def window_bounds(cursor_time)
        args = unit == :week ? [:monday] : []
        start_time = cursor_time.public_send(:"beginning_of_#{unit}", *args)
        [start_time, start_time + 1.public_send(unit)]
      end
    end
  end
end
