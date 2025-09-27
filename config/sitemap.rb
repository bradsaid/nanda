# config/sitemap.rb
# gem 'sitemap_generator'

SitemapGenerator::Sitemap.default_host = ENV.fetch("APP_HOST", "https://www.nakedandafraidfan.com")
SitemapGenerator::Sitemap.compress = true
SitemapGenerator::Sitemap.create_index = true
SitemapGenerator::Sitemap.namer = SitemapGenerator::SimpleNamer.new(:sitemap, :start => 1)
# Optional: store on S3/CloudFront in production (Heroku-safe)
if Rails.env.production? && ENV["SITEMAPS_HOST"].present?
  SitemapGenerator::Sitemap.public_path  = "tmp/"
  SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"
  SitemapGenerator::Sitemap.sitemaps_host = ENV["SITEMAPS_HOST"] # e.g. https://dxxxx.cloudfront.net
  SitemapGenerator::Sitemap.adapter = SitemapGenerator::S3Adapter.new(
    fog_provider: "AWS",
    aws_access_key_id:     ENV["AWS_ACCESS_KEY_ID"],
    aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
    aws_region:            ENV.fetch("AWS_REGION", "us-east-1")
  )
end

SitemapGenerator::Sitemap.create do
  # ---------- Static / collection pages ----------
  add root_path,                 changefreq: "daily",  priority: 1.0
  add home_path,                 changefreq: "daily",  priority: 0.9
  add about_path,                changefreq: "monthly",priority: 0.5
  add podcasts_path,             changefreq: "weekly", priority: 0.6

  add survivors_path,            changefreq: "daily",  priority: 0.8
  add episodes_path,             changefreq: "daily",  priority: 0.8
  add items_path,                changefreq: "weekly", priority: 0.7
  add seasons_path,              changefreq: "weekly", priority: 0.7
  add series_index_path,         changefreq: "weekly", priority: 0.7

  # ---------- Filters / facets ----------
  # /episodes/by_country/:country
  Location.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country).each do |country|
    add by_country_episodes_path(country: country), changefreq: "weekly", priority: 0.6
  end

  # /items/types/:item_type
  Item.distinct.order(:item_type).pluck(:item_type).compact.each do |t|
    next if t.blank?
    add type_items_path(item_type: t), changefreq: "weekly", priority: 0.6
  end

  # ---------- Survivors ----------
  Survivor.find_in_batches(batch_size: 1000) do |batch|
    batch.each do |s|
      add survivor_path(s), lastmod: s.updated_at, priority: 0.7, changefreq: "weekly"
    end
  end

  # ---------- Episodes ----------
  Episode.includes(:season, :location).find_in_batches(batch_size: 1000) do |batch|
    batch.each do |e|
      add episode_path(e), lastmod: e.updated_at, priority: 0.7, changefreq: "weekly"
    end
  end

  # ---------- Items ----------
  Item.find_in_batches(batch_size: 1000) do |batch|
    batch.each do |i|
      add item_path(i), lastmod: i.updated_at, priority: 0.5, changefreq: "monthly"
    end
  end

  # ---------- Seasons ----------
  Season.includes(:series).find_in_batches(batch_size: 1000) do |batch|
    batch.each do |season|
      add season_path(season), lastmod: season.updated_at, priority: 0.6, changefreq: "monthly"
    end
  end

  # ---------- Series ----------
  Series.find_each do |series|
    add series_path(series), lastmod: series.updated_at, priority: 0.6, changefreq: "monthly"
  end

  # Optional: ping search engines after create
  # SitemapGenerator::Sitemap.ping_search_engines
end
