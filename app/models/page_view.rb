class PageView < ApplicationRecord
  scope :recent,     ->(n = 50) { order(created_at: :desc).limit(n) }
  scope :today,      -> { where(created_at: Date.current.all_day) }
  scope :this_week,  -> { where(created_at: Date.current.all_week) }
  scope :this_month, -> { where(created_at: Date.current.all_month) }

  def self.top_pages(limit = 20)
    group(:path).order("count_all desc").limit(limit).count
  end

  def self.top_sections(limit = 20)
    select("controller_name, action_name, COUNT(*) AS hits")
      .group(:controller_name, :action_name)
      .order("hits DESC")
      .limit(limit)
  end

  CST_DATE_SQL = "DATE(created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Chicago')"

  def self.daily_counts(days = 30)
    where(created_at: days.days.ago..)
      .group(Arel.sql(CST_DATE_SQL))
      .order(Arel.sql("#{CST_DATE_SQL} ASC"))
      .count
  end

  def self.daily_unique_counts(days = 30)
    col = where.not(visitor_id: [nil, ""]).exists? ? :visitor_id : :session_id
    where(created_at: days.days.ago..)
      .group(Arel.sql(CST_DATE_SQL))
      .distinct
      .count(col)
  end

  def self.unique_visitors
    if where.not(visitor_id: [nil, ""]).exists?
      distinct.count(:visitor_id)
    else
      distinct.count(:session_id)
    end
  end

  def self.top_countries(limit = 15)
    where.not(country: [nil, ""])
      .group(:country)
      .order("count_all desc")
      .limit(limit)
      .count
  end

  def self.top_browsers(limit = 10)
    where.not(browser: [nil, ""])
      .group(:browser)
      .order("count_all desc")
      .limit(limit)
      .count
  end

  def self.device_breakdown
    where.not(device_type: [nil, ""])
      .group(:device_type)
      .count
  end

  def self.avg_duration
    where("duration_seconds > 0").average(:duration_seconds)&.round(1)
  end

  def self.avg_duration_by_page(limit = 25)
    where("duration_seconds > 0")
      .group(:path)
      .select("path, ROUND(AVG(duration_seconds), 1) AS avg_seconds, COUNT(*) AS views")
      .order("avg_seconds DESC")
      .limit(limit)
  end

  def self.top_referrer_domains(limit = 10)
    where.not(referrer_domain: [nil, ""])
      .where.not(referrer_domain: "nakedandafraidfan.com")
      .group(:referrer_domain)
      .order("count_all desc")
      .limit(limit)
      .count
  end

  # Returns average minutes between new unique visitors over the last 7 days
  def self.unique_visitor_frequency
    scope = where(created_at: 7.days.ago..)
    col = scope.where.not(visitor_id: [nil, ""]).exists? ? :visitor_id : :session_id
    unique_count = scope.distinct.count(col)
    return nil if unique_count < 2

    first_visit = scope.minimum(:created_at)
    last_visit  = scope.maximum(:created_at)
    return nil unless first_visit && last_visit

    elapsed_minutes = (last_visit - first_visit) / 60.0
    (elapsed_minutes / unique_count).round(1)
  end
end
