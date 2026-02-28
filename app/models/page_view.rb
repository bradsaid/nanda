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
end
