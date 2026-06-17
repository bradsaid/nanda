class ApplicationController < ActionController::Base
  include TrackPageViews

  # TEMP: no auth anywhere

  allow_browser versions: :modern

  helper_method :current_user, :logged_in?, :admin_signed_in?
  def current_user = nil
  def logged_in?   = false

  # True when the visitor is signed in as a full admin or episode_editor.
  # Used to conditionally reveal admin-only details on public pages
  # (e.g. per-survivor view counts on the Survivors index).
  def admin_signed_in?
    return @_admin_signed_in if defined?(@_admin_signed_in)
    user = User.find_by(id: session[:user_id]) if session[:user_id]
    @_admin_signed_in = !!(user && (user.admin? || user.episode_editor?))
  end

  def require_login;  true; end
  def require_admin;  true; end
  def require_authentication; true; end
  def resume_session; true; end

  if Rails.env.production?
    allow_browser versions: :modern
  end

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

  # Subquery that returns each (survivor, season) and the air_date of the
  # LAST appearance where the admin recorded a result (any of success,
  # tap_out, medical_tap_out, elimination). Used to clip episode counts on
  # continuous-story seasons so episodes airing after a survivor's exit are
  # not counted toward their total.
  def appearance_exits_join
    <<~SQL.squish
      LEFT JOIN (
        SELECT
          a.survivor_id,
          e.season_id,
          MAX(e.air_date) AS exit_air_date
        FROM appearances a
        JOIN episodes e ON e.id = a.episode_id
        WHERE a.result IS NOT NULL
        GROUP BY a.survivor_id, e.season_id
      ) appearance_exits
        ON appearance_exits.survivor_id = appearances.survivor_id
       AND appearance_exits.season_id   = episodes.season_id
    SQL
  end

  # COUNT(DISTINCT episodes.id) with a per-survivor tap-out clamp on
  # continuous-story seasons. Requires that the outer query also includes the
  # appearance_exits_join. For non-continuous seasons or survivors with no
  # result recorded, every appearance episode is counted as before.
  def episodes_total_capped_sql(alias_name = "episodes_total_count")
    <<~SQL.squish
      COUNT(DISTINCT episodes.id) FILTER (
        WHERE NOT #{continuous_flag_sql}
           OR appearance_exits.exit_air_date IS NULL
           OR episodes.air_date <= appearance_exits.exit_air_date
      ) AS #{alias_name}
    SQL
  end

  # DISTINCT episodes normally; collapse to 1 per season when continuous.
  def collapsed_episodes_sql(alias_name = "episodes_collapsed_count")
    <<~SQL.squish
      COUNT(DISTINCT
        CASE
          WHEN NOT #{continuous_flag_sql}
            THEN episodes.id::text
          ELSE 'season-' || seasons.id::text
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

  # optional: collapse continuous stories to 1 per season
  def collapsed_episode_presence_for_source_sql(source, alias_name = "ep_collapsed")
    <<~SQL.squish
      COUNT(DISTINCT
        CASE
          WHEN appearance_items.source='#{source}' AND NOT #{continuous_flag_sql}
            THEN episodes.id::text
          WHEN appearance_items.source='#{source}' AND #{continuous_flag_sql}
            THEN 'season-' || seasons.id::text
        END
      ) AS #{alias_name}
    SQL
  end

  def per_episode_presence_sql(alias_name = "ep_count")
    <<~SQL.squish
      COUNT(DISTINCT episodes.id) AS #{alias_name}
    SQL
  end

  # Same, but collapse continuous stories to 1 per season
  def collapsed_episode_presence_sql(alias_name = "ep_collapsed")
    <<~SQL.squish
      COUNT(DISTINCT
        CASE
          WHEN #{continuous_flag_sql} THEN ('season-' || seasons.id::text)
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
