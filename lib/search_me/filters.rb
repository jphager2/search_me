module SearchMe
  module Filters
    def filter_month_quarter_or_year(month, quarter, year)
      if month
        month(month, year)
      elsif quarter
        quarter(quarter, year)
      elsif year
        year(year)
      else
        self
      end
    end

    def filter_year(year)
      return self if year.nil? 

      date = Date.new(year, 1, 1)
      build_between_query_for(year_for_date(date))
    end

    def filter_month(month, year)
      return self if month.nil? 

      year ||= Date.today.year
      date = Date.new(year, month, 1)
      build_between_query_for(month_for_date(date))
    end

    def filter_quarter(quarter, year)
      return self if quarter.nil? || quarter > 4 or quarter < 1

      year ||= Date.today.year
      month = (quarter - 1) * 3 + 1
      date = Date.new(year, month, 1)
      build_between_query_for(quarter_for_date(date))
    end

    private
    def duration(duration)
      today = Date.today

      duration = case duration
      when "current_month"
        month_for_date(today)
      when "last_month"
        month_for_date(1.month.ago)
      when "f_last_month"
        month_for_date(2.month.ago)
      when "last_quarter"
        quarter_for_date(today.beginning_of_quarter - 1)
      when "current_year"
        year_for_date(today)
      when "last_year"
        year_for_date(1.year.ago)
      when "f_last_year"
        year_for_date(2.year.ago)
      else
        nil # do nothing
      end
      if duration
        build_between_query_for(duration)
      else
        self 
      end
    end

    def build_between_query_for(duration)
      field = SearchMe.config.time_field
      in_created_at = "(#{field} > ?  AND  #{field} < ?)"
      on_created_at = "(#{field} = ?) OR  (#{field} = ?)"
      self.where( 
        "#{in_created_at} OR #{on_created_at}", *duration, *duration
      )
    end

    def month_for_date(date)
      [date.beginning_of_month, date.end_of_month]
    end

    def year_for_date(date)
      [date.beginning_of_year, date.end_of_year]
    end

    def quarter_for_date(date)
      [date.beginning_of_quarter, date.end_of_quarter]
    end
  end
end
