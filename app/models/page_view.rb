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

  def self.daily_counts(days = 30)
    where(created_at: days.days.ago..)
      .group("DATE(created_at)")
      .order("date_created_at")
      .count
  end

  def self.unique_visitors
    distinct.count(:session_id)
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

  def self.top_referrer_domains(limit = 10)
    where.not(referrer_domain: [nil, ""])
      .group(:referrer_domain)
      .order("count_all desc")
      .limit(limit)
      .count
  end
end
