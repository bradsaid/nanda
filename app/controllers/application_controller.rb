class ApplicationController < ActionController::Base
  # TEMP: no auth anywhere

  allow_browser versions: :modern

  helper_method :current_user, :logged_in?
  def current_user = nil
  def logged_in?   = false

  def require_login;  true; end
  def require_admin;  true; end
  def require_authentication; true; end
  def resume_session; true; end

  private

  # true if either the season or the series is marked continuous
  def continuous_flag_sql
    "(COALESCE(seasons.continuous_story, false) OR COALESCE(series.continuous_story, false))"
  end

  # ITEM totals: per-episode presence for continuous; sum quantities for normal
  def adjusted_total_expr
    <<~SQL.squish
      COUNT(DISTINCT episodes.id) FILTER (WHERE #{continuous_flag_sql})
      +
      COALESCE(SUM(appearance_items.quantity) FILTER (WHERE NOT #{continuous_flag_sql}), 0)
    SQL
  end

  def adjusted_total_sql(total_alias: "total")
    "(#{adjusted_total_expr}) AS #{total_alias}"
  end

  def adjusted_total_for_source_expr(source)
    <<~SQL.squish
      COUNT(DISTINCT episodes.id)
        FILTER (WHERE #{continuous_flag_sql} AND appearance_items.source='#{source}')
      +
      COALESCE(SUM(appearance_items.quantity)
        FILTER (WHERE NOT #{continuous_flag_sql} AND appearance_items.source='#{source}'), 0)
    SQL
  end

  def adjusted_total_for_source_sql(source, total_alias: "#{source}_total")
    "(#{adjusted_total_for_source_expr(source)}) AS #{total_alias}"
  end

  # EPISODE counts for survivors: distinct episodes for normal; 1 per series if continuous
  def adjusted_episodes_expr
    <<~SQL.squish
      COALESCE(COUNT(DISTINCT episodes.id) FILTER (WHERE NOT #{continuous_flag_sql}), 0)
      +
      COALESCE(COUNT(DISTINCT series.id)   FILTER (WHERE #{continuous_flag_sql}), 0)
    SQL
  end

  def adjusted_episodes_sql(alias_name = "episodes_adjusted_count")
    "(#{adjusted_episodes_expr}) AS #{alias_name}"
  end

  # DISTINCT episodes normally; collapse to 1 per series when continuous.
  def collapsed_episodes_sql(alias_name = "episodes_collapsed_count")
    <<~SQL.squish
      COUNT(DISTINCT
        CASE
          WHEN NOT #{continuous_flag_sql}
            THEN episodes.id::text
          ELSE 'series-' || series.id::text
        END
      ) AS #{alias_name}
    SQL
  end

  # episodes where a source appears at least once (no quantity)
  def per_episode_presence_for_source_sql(source, alias_name = "ep_count")
    <<~SQL.squish
      COUNT(DISTINCT episodes.id)
        FILTER (WHERE appearance_items.source='#{source}') AS #{alias_name}
    SQL
  end

  # optional: collapse continuous series to 1 per series
  def collapsed_episode_presence_for_source_sql(source, alias_name = "ep_collapsed")
    <<~SQL.squish
      COUNT(DISTINCT
        CASE
          WHEN appearance_items.source='#{source}' AND NOT #{continuous_flag_sql}
            THEN episodes.id::text
          WHEN appearance_items.source='#{source}' AND #{continuous_flag_sql}
            THEN 'series-' || series.id::text
        END
      ) AS #{alias_name}
    SQL
  end

  def per_episode_presence_sql(alias_name = "ep_count")
    <<~SQL.squish
      COUNT(DISTINCT episodes.id) AS #{alias_name}
    SQL
  end

  # Same, but collapse continuous seasons/series to 1 per series
  def collapsed_episode_presence_sql(alias_name = "ep_collapsed")
    <<~SQL.squish
      COUNT(DISTINCT
        CASE
          WHEN #{continuous_flag_sql} THEN ('series-' || series.id::text)
          ELSE episodes.id::text
        END
      ) AS #{alias_name}
    SQL
  end

  # Count presence (NOT quantities):
  # - non-continuous: distinct episodes
  # - continuous:     distinct series
  def adjusted_presence_expr
    <<~SQL.squish
      COALESCE(
        COUNT(DISTINCT episodes.id) FILTER (WHERE NOT #{continuous_flag_sql}), 0
      )
      +
      COALESCE(
        COUNT(DISTINCT series.id)   FILTER (WHERE #{continuous_flag_sql}), 0
      )
    SQL
  end

  def adjusted_presence_sql(total_alias: "total")
    "(#{adjusted_presence_expr}) AS #{total_alias}"
  end

  def adjusted_presence_for_source_expr(source)
    <<~SQL.squish
      COALESCE(
        COUNT(DISTINCT episodes.id)
          FILTER (WHERE NOT #{continuous_flag_sql} AND appearance_items.source='#{source}'), 0
      )
      +
      COALESCE(
        COUNT(DISTINCT series.id)
          FILTER (WHERE #{continuous_flag_sql} AND appearance_items.source='#{source}'), 0
      )
    SQL
  end

  def adjusted_presence_for_source_sql(source, total_alias: "#{source}_total")
    "(#{adjusted_presence_for_source_expr(source)}) AS #{total_alias}"
  end


end
