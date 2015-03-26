module SearchMe
  module Filters
    def filter_month_quarter_or_year(month=nil, quarter=nil, year=nil)
      month, quarter, year = sanitize_params(month, quarter, year)
      if month
        filter_month(month, year)
      elsif quarter
        filter_quarter(quarter, year)
      else
        filter_year(year)
      end
    end

    def filter_year(year = nil)
      year = sanitize_params(year).first

      year ||= Date.today.year
      date   = Date.new(year, 1, 1)

      build_between_query_for(year_for_date(date))
    end

    def filter_month(month = nil, year = nil)
      month, year = sanitize_params(month, year)

      month ||= Date.today.month
      year  ||= Date.today.year
      date    = Date.new(year, month, 1)

      build_between_query_for(month_for_date(date))
    end

    def filter_quarter(quarter = nil, year = nil)
      quarter, year = sanitize_params(quarter, year)
      quarter ||= (Date.today.month - 1) / 3 + 1
      return self if quarter > 4

      year    ||= Date.today.year
      month     = (quarter - 1) * 3 + 1
      date      = Date.new(year, month, 1)
      
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

    def sanitize_params(*params)
      # i.e. Integer or nil. Also no zero year, month, day
      params.map { |p| p.to_i if p.present? && !p.to_i.zero? }
    end
  end
end
